// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseStrategyOtherPairNonReentrant} from "./BaseStrategyOtherPairNonReentrant.sol";

contract StrategyOtherPairCometh is BaseStrategyOtherPairNonReentrant {
    address public constant COMETH_ROUTER =
        0x93bcDc45f7e62f89a8e901DC4A0E2c6C427D9F25;
    string private pairName;

    constructor(
        address rewards,
        address lp,
        address tokenA,
        address tokenB,
        string memory _pairName
    )
        BaseStrategyOtherPairNonReentrant(
            rewards,
            lp,
            tokenA,
            tokenB,
            COMETH_ROUTER
        )
    {
        pairName = _pairName;
    }

    // **** Views ****

    function getPairName() external view returns (string memory) {
        return pairName;
    }
}
