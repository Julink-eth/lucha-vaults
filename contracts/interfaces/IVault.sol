// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IJar} from "./IJar.sol";

interface IVault is IJar {
    function getLastDepositTime(address _user) external view returns (uint256);

    function getTokensStaked(address _user) external view returns (uint256);

    function totalShares() external view returns (uint256);
}
