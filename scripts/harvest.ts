// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

const strategies = [
  "0x8e9d261FB991935917cbcb0945168908461419A7",
  "0x6C57Bc7eEC2144Eb9ab6509556051E1fF6D1C024",
];

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  for (let i = 0; i < strategies.length; i++) {
    const strategy = strategies[i];
    console.log("Start harvesting strategy ", strategy);
    const StrategyOtherPairCometh = await ethers.getContractFactory(
      "StrategyOtherPairCometh"
    );
    const strategyOtherPairCometh = StrategyOtherPairCometh.attach(strategy);
    const tx = await strategyOtherPairCometh.harvest();
    await tx.wait();

    console.log("Strategy harvested");
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
