// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ContractReceipt } from "ethers";
import { ethers } from "hardhat";

const LUCHA = "0x6749441Fdc8650b5b5a854ed255C82EF361f1596";
const MUST = "0x9C78EE466D6Cb57A4d01Fd887D2b5dFb2D46288f";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const vaultDeployerAddr = "0xC2ad7b1a3C6878bc253A1ee609ee5C017294e8c2";
  const strategyDeployerAddr = "0xD1E1902BdAeAA038066C6bB62a8316a3b2f3160c";

  const stakingContract = "0xe11f861dD5cE8407bb24dFD13b9710c0295276D6";
  const lpContract = "0x98503d87Aa4E9c84fF5D2e558295a0967fBBBEFF";
  const tokenA = MUST;
  const tokenB = LUCHA;
  const pairName = "LUCHA-MUST";

  const rewardWallet = "0x72104d619BaEDf632936d9dcE38C089CA3bf12Dc";
  const devWallet = "0xdF789493B9C1aa8B78D467a094FDEb5e44c18e9B";
  const daoTreasury = "0x0Cb11b92Fa5C30eAfe4aE84B7BB4dF3034C38b9d";

  const StrategyDeployerCometh = await ethers.getContractFactory(
    "StrategyDeployerCometh"
  );
  const strategyDeployerCometh =
    StrategyDeployerCometh.attach(strategyDeployerAddr);

  const VaultDeployer = await ethers.getContractFactory("VaultDeployer");
  const vaultDeployer = VaultDeployer.attach(vaultDeployerAddr);
  const StrategyOtherPairCometh = await ethers.getContractFactory(
    "StrategyOtherPairCometh"
  );

  console.log("Deploying strategy");
  let deployTx = await strategyDeployerCometh.deploy(
    stakingContract,
    lpContract,
    tokenA,
    tokenB,
    pairName,
    vaultDeployer.address
  );
  let receipt = await deployTx.wait();
  const strategy = getEventArg(receipt, "Deployed", 0);
  const strategyOtherPairCometh = StrategyOtherPairCometh.attach(strategy);
  console.log("Deploying vault");
  deployTx = await vaultDeployer.deploy(strategy);
  receipt = await deployTx.wait();
  const vault = getEventArg(receipt, "Deployed", 1);

  console.log("Adding fee collectors");
  let tx = await strategyOtherPairCometh.addFeeCollector(rewardWallet, 100);
  await tx.wait();
  tx = await strategyOtherPairCometh.addFeeCollector(devWallet, 100);
  await tx.wait();
  tx = await strategyOtherPairCometh.addFeeCollector(daoTreasury, 200);
  await tx.wait();
  console.log("Finished adding fee collectors");

  console.log("Strategy contract created : ", strategy);
  console.log("Vault contract created : ", vault);
}

function getEventArg(
  receipt: ContractReceipt,
  eventName: string,
  argIndex: number
): string {
  const events = receipt.events?.filter((x) => {
    return x.event === eventName;
  });

  if (events && events.length > 0) {
    const event = events[0];
    return event.args ? event.args[argIndex] : "";
  }

  return "";
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
