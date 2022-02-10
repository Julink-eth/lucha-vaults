// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IVault} from "./interfaces/IVault.sol";

abstract contract VaultBase is IVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Info of each user
    struct UserInfo {
        uint256 shares; // User shares
        uint256 lastDepositTime;
        uint256 tokensStaked; // Number of tokens staked, only used to calculate profit on the frontend (different than shares)
    }

    uint256 public constant KEEP_MAX = 10000;

    /* ========== STATE VARIABLES ========== */

    // Info of each user
    mapping(address => UserInfo) public userInfo;

    // The total # of shares issued
    uint256 public override totalShares;
    // For vaults that are farming pools with a deposit fee
    uint256 public depositFee = 0;

    IERC20 public override token;
    address public override strategy;

    constructor(IStrategy _strategy) {
        require(address(_strategy) != address(0), "no strategy");
        token = IERC20(_strategy.want());
        strategy = address(_strategy);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getRatio() public view override returns (uint256) {
        return balance().mul(1e18).div(totalShares);
    }

    function balance() public view override returns (uint256) {
        return
            token.balanceOf(address(this)).add(IStrategy(strategy).balanceOf());
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return userInfo[_user].shares;
    }

    function getLastDepositTime(address _user)
        public
        view
        override
        returns (uint256)
    {
        return userInfo[_user].lastDepositTime;
    }

    function getTokensStaked(address _user)
        public
        view
        override
        returns (uint256)
    {
        return userInfo[_user].tokensStaked;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function depositAll() external override {
        deposit(token.balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) public override nonReentrant {
        require(msg.sender == tx.origin, "no contracts");

        uint256 _pool = balance();
        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after.sub(_before); // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalShares == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalShares)).div(_pool);
        }

        //when farming pools with a deposit fee
        if (depositFee > 0) {
            uint256 fee = shares.mul(depositFee).div(KEEP_MAX);
            shares = shares.sub(fee);
        }

        totalShares = totalShares.add(shares);

        UserInfo storage user = userInfo[msg.sender];
        user.shares = user.shares.add(shares);
        user.lastDepositTime = block.timestamp;
        user.tokensStaked = user.tokensStaked.add(_amount);

        earn();
        emit Deposited(msg.sender, _amount);
    }

    function earn() internal {
        uint256 _bal = token.balanceOf(address(this));
        token.safeTransfer(strategy, _bal);
        IStrategy(strategy).deposit();
    }

    // Withdraw all tokens and claim rewards.
    function withdrawAll() external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _shares = user.shares;
        uint256 r = (balance().mul(_shares)).div(totalShares);

        // Check balance
        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IStrategy(strategy).withdraw(_withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        totalShares = totalShares.sub(_shares);
        user.shares = user.shares.sub(_shares);
        user.tokensStaked = 0;

        token.safeTransfer(msg.sender, r);
        emit Withdrawn(msg.sender, r);
    }

    // Withdraw all tokens without caring about rewards in the event that the reward mechanism breaks.
    function emergencyWithdraw() public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _shares = user.shares;
        uint256 r = (balance().mul(_shares)).div(totalShares);

        // Check balance
        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IStrategy(strategy).withdraw(_withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        if (_shares <= totalShares) {
            totalShares = totalShares.sub(_shares);
        } else {
            totalShares = 0;
        }
        user.shares = 0;
        user.tokensStaked = 0;

        token.safeTransfer(msg.sender, r);
        emit Withdrawn(msg.sender, r);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    //shouldn't be farming things with a high deposit fee in the first place
    function setPoolDepositFee(uint256 _depositFee) public onlyOwner {
        require(_depositFee <= 1000, "?");
        depositFee = _depositFee;
    }

    /* ========== EVENTS ========== */

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
}

contract GenericVault is VaultBase {
    constructor(IStrategy _strategy) VaultBase(_strategy) {}
}
