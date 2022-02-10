// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IUniswapRouterV2} from "./interfaces/IUniswapRouterV2.sol";

abstract contract BaseStrategy is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Tokens
    address public want; //The LP token, Harvest calls this "rewardToken"

    // Contracts
    address public jar; //The vault/jar contract

    // Dex
    address public defaultRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; //Quickswap router
    address public currentRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; //Quickswap router

    constructor(address _want, address _currentRouter) {
        require(_want != address(0));

        want = _want;
        currentRouter = _currentRouter;
    }

    // **** Modifiers **** //

    //prevent unauthorized smart contracts from calling harvest()
    modifier onlyHumanOrWhitelisted() {
        require(
            msg.sender == tx.origin ||
                msg.sender == owner() ||
                msg.sender == address(this),
            "not authorized"
        );
        _;
    }

    // **** Views **** //

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view virtual returns (uint256);

    function getHarvestable() external view virtual returns (uint256[] memory);

    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    // **** Setters **** //

    function setJar(address _jar) external onlyOwner {
        require(jar == address(0), "jar set");
        jar = _jar;
        emit SetJar(_jar);
    }

    // **** State mutations **** //
    function deposit() public virtual;

    // Withdraw partial funds, normally used with a jar withdrawal
    function withdraw(uint256 _amount) external {
        require(msg.sender == jar, "!jar");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }

        IERC20(want).safeTransfer(jar, _amount);
    }

    function _withdrawAll() internal {
        _withdrawSome(balanceOfPool());
    }

    function _withdrawSome(uint256 _amount) internal virtual returns (uint256);

    function harvest() public virtual;

    // **** Internal functions ****
    function _swapUniswapWithPath(address[] memory path, uint256 _amount)
        internal
    {
        require(path[1] != address(0), "address 0");

        //We check the price with 2 dexes and keep the best one
        uint256 amoutOutCurrentRouter = IUniswapRouterV2(currentRouter)
            .getAmountsOut(_amount, path)[path.length - 1];

        uint256 amoutOutDefaultRouter = IUniswapRouterV2(defaultRouter)
            .getAmountsOut(_amount, path)[path.length - 1];

        address routerUsed = currentRouter;
        if (amoutOutDefaultRouter > amoutOutCurrentRouter) {
            routerUsed = defaultRouter;
        }

        // Swap with uniswap
        IERC20(path[0]).safeApprove(routerUsed, 0);
        IERC20(path[0]).safeApprove(routerUsed, _amount);

        IUniswapRouterV2(routerUsed).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    // **** Events **** //
    event SetJar(address indexed jar);
}
