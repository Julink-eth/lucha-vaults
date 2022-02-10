// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import {GenericVault} from "./GenericVault.sol";
import {StrategyOtherPairCometh} from "./StrategyOtherPairCometh.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

//Deploys the vault for the strategy
contract VaultDeployer is Ownable {
    bool public finalized = false;

    struct VaultData {
        address strat;
        address vault;
    }

    VaultData[] public deployedVaults;

    function deploy(address strategy) public onlyOwner {
        require(finalized == false, "vaults finalized");

        address jar = address(new GenericVault(IStrategy(strategy)));

        StrategyOtherPairCometh(strategy).setJar(jar);
        Ownable(strategy).transferOwnership(msg.sender);
        Ownable(jar).transferOwnership(msg.sender);

        emit Deployed(strategy, jar);
    }

    function getDeployedVaults()
        public
        view
        returns (VaultData[] memory vaultData)
    {
        uint256 length = deployedVaults.length;
        vaultData = new VaultData[](length);

        for (uint256 i = 0; i < length; i++) {
            vaultData[i] = deployedVaults[i];
        }
    }

    //Prevent any more vaults from being deployed
    function finalizeDeployment() external onlyOwner {
        finalized = true;
    }

    event Deployed(address indexed strategy, address indexed jar);
}
