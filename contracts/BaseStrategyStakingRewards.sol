// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BaseStrategy} from "./BaseStrategy.sol";
import {IStakingMultiRewards} from "./interfaces/IStakingMultiRewards.sol";

abstract contract BaseStrategyStakingRewards is BaseStrategy {
    address public rewards;

    // **** Getters ****
    constructor(
        address _rewards,
        address _want,
        address _currentRouter
    ) BaseStrategy(_want, _currentRouter) {
        rewards = _rewards;
    }

    function balanceOfPool() public view override returns (uint256) {
        return IStakingMultiRewards(rewards).balanceOf(address(this));
    }

    function getHarvestable()
        external
        view
        override
        returns (uint256[] memory)
    {
        return IStakingMultiRewards(rewards).earned(address(this));
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).approve(rewards, 0);
            IERC20(want).approve(rewards, _want);
            IStakingMultiRewards(rewards).stake(_want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IStakingMultiRewards(rewards).withdraw(_amount);
        return _amount;
    }

    /* **** Mutative functions **** */

    function _getReward() internal {
        IStakingMultiRewards(rewards).getReward();
    }

    // **** Admin functions ****

    // Added to support recovering LP Rewards from other systems to be distributed to holders
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) public onlyOwner {
        // Admin cannot withdraw the staking or harvested token from the contract
        require(token != want, "token != want");
        IERC20(token).transfer(recipient, amount);
    }
}
