// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IStakingMultiRewards {
    // Views
    function earned(address account) external view returns (uint256[] memory);

    function getRewardsTokens() external view returns (address[] memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    // Mutative

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;
}
