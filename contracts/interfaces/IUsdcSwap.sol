// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//Interface to interact with the MAi finance ANCHOR contract
interface IUsdcSwap {
    function swapFrom(uint256 amount) external;

    function swapTo(uint256 amount) external;
}
