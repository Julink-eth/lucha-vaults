// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import {StrategyOtherPairCometh} from "./StrategyOtherPairCometh.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

//Deploys strategies for TokenA/TokenB pairs
//Make sure that a pair for rewardToken/TokenA exists
contract StrategyDeployerCometh is Ownable {
    bool public finalized = false;

    function deploy(
        address rewards,
        address lp,
        address tokenA,
        address tokenB,
        string memory pairName,
        address vaultDeployer
    ) public onlyOwner {
        require(finalized == false, "vaults finalized");

        address strategy = address(
            new StrategyOtherPairCometh(rewards, lp, tokenA, tokenB, pairName)
        );

        Ownable(strategy).transferOwnership(vaultDeployer);

        emit Deployed(strategy);
    }

    //Prevent any more vaults from being deployed
    function finalizeDeployment() external onlyOwner {
        finalized = true;
    }

    event Deployed(address indexed strategy);
}
