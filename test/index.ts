import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ContractReceipt } from "ethers";
import { ethers } from "hardhat";
import {
  ERC20,
  // eslint-disable-next-line camelcase
  ERC20__factory,
  GenericVault,
  IUniswapRouterV2,
  StrategyOtherPairCometh,
} from "../typechain";

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

describe("StrategyDeployerCometh LUCHA/WMATIC", function () {
  const comethSwapRouter = "0x93bcDc45f7e62f89a8e901DC4A0E2c6C427D9F25";
  const stakingContract = "0x0d008974359e5aD1B64c4edc4de3C46ED662b6D8";
  const lpContract = "0x5E1CD1b923674e99dF95CE0f910dcf5a58A3ca2D";
  const WMATIC = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270";
  const tokenA = "0x9c78ee466d6cb57a4d01fd887d2b5dfb2d46288f"; // MUST
  const tokenB = "0x6749441Fdc8650b5b5a854ed255C82EF361f1596"; // LUCHA
  const tokenC = "0x42d61D766B85431666B39B89C43011f24451bFf6"; // PSP
  const rewardWallet = "0x72104d619BaEDf632936d9dcE38C089CA3bf12Dc";
  const devWallet = "0xdF789493B9C1aa8B78D467a094FDEb5e44c18e9B";
  const daoTreasury = "0x0Cb11b92Fa5C30eAfe4aE84B7BB4dF3034C38b9d";
  const pairName = "LUCHA-WMATIC";
  let accounts = [] as SignerWithAddress[];
  let account1 = "";
  let deadline: number;
  const oneWeekSeconds = 604800;
  let oneWeekLater: number;
  const toSpend = ethers.utils.parseUnits("1");
  // eslint-disable-next-line camelcase
  let ERC20Factory: ERC20__factory;
  let genericVault: GenericVault;
  let strategyOtherPairCometh: StrategyOtherPairCometh;
  let router: IUniswapRouterV2;
  let erc20B: ERC20;
  let erc20C: ERC20;
  const pathToB = [WMATIC, tokenB];
  let erc20LP: ERC20;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    account1 = accounts[0].address;
    const StrategyDeployerCometh = await ethers.getContractFactory(
      "StrategyDeployerCometh"
    );
    const VaultDeployer = await ethers.getContractFactory("VaultDeployer");
    const GenericVault = await ethers.getContractFactory("GenericVault");
    const StrategyOtherPairCometh = await ethers.getContractFactory(
      "StrategyOtherPairCometh"
    );
    ERC20Factory = await ethers.getContractFactory("ERC20");

    const vaultDeployer = await VaultDeployer.deploy();
    const strategyDeployerCometh = await StrategyDeployerCometh.deploy();

    await strategyDeployerCometh.deployed();
    await vaultDeployer.deployed();

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
    strategyOtherPairCometh = StrategyOtherPairCometh.attach(strategy);
    deployTx = await vaultDeployer.deploy(strategy);
    receipt = await deployTx.wait();
    const vault = getEventArg(receipt, "Deployed", 1);

    strategyOtherPairCometh.addFeeCollector(rewardWallet, 100);
    strategyOtherPairCometh.addFeeCollector(devWallet, 100);
    strategyOtherPairCometh.addFeeCollector(daoTreasury, 200);

    genericVault = GenericVault.attach(vault);
    router = await ethers.getContractAt("IUniswapRouterV2", comethSwapRouter);
    erc20B = ERC20Factory.attach(tokenB);
    erc20C = ERC20Factory.attach(tokenC);
    erc20LP = ERC20Factory.attach(lpContract);
    deadline = Math.floor(new Date().getTime() / 1000) + 1000 * 1000;
    oneWeekLater = Math.floor(new Date().getTime() / 1000);
  });

  it("Should be able to add LP and withdraw more LP with the compounded rewards", async function () {
    // Get LUCHA tokens
    await router.swapExactETHForTokens(toSpend, pathToB, account1, deadline, {
      value: toSpend,
    });

    const balanceB = await erc20B.balanceOf(account1);

    // Add liquidity
    await erc20B.approve(comethSwapRouter, balanceB);
    await router.addLiquidityETH(tokenB, balanceB, 0, 0, account1, deadline, {
      value: toSpend,
    });

    const balanceLP = await erc20LP.balanceOf(account1);
    console.log("balanceLP", balanceLP);

    // Deposit LP in vaults
    await erc20LP.approve(genericVault.address, balanceLP);
    await genericVault.depositAll();
    let newBalanceLP = await erc20LP.balanceOf(account1);

    expect(newBalanceLP.toString()).to.equal("0");

    oneWeekLater =
      Math.floor(new Date().getTime() / 1000) + 1000 * oneWeekSeconds;
    await ethers.provider.send("evm_mine", [oneWeekLater]);

    await strategyOtherPairCometh.harvest();
    await genericVault.withdrawAll();
    newBalanceLP = await erc20LP.balanceOf(account1);

    expect(newBalanceLP > balanceLP);
    console.log("newBalanceLP", newBalanceLP);
  }).timeout(80000);

  it.only(
    "Multiple accounts should be able to add LP and withdraw more LP with the compounded rewards",
    async function () {
      deadline = oneWeekLater + 1000 * 1000;
      const balancesLP = [];
      for (let i = 0; i < 3; i++) {
        const account = accounts[i];
        const accountAddr = accounts[i].address;
        // Get LUCHA tokens
        await router
          .connect(account)
          .swapExactETHForTokens(toSpend, pathToB, accountAddr, deadline, {
            value: toSpend,
          });

        const balanceB = await erc20B.balanceOf(accountAddr);

        // Add liquidity
        await erc20B.connect(account).approve(comethSwapRouter, balanceB);
        await router
          .connect(account)
          .addLiquidityETH(tokenB, balanceB, 0, 0, accountAddr, deadline, {
            value: toSpend,
          });

        const balanceLP = await erc20LP.balanceOf(accountAddr);
        balancesLP.push(balanceLP);

        // Deposit LP in vaults
        await erc20LP.connect(account).approve(genericVault.address, balanceLP);
        await genericVault.connect(account).depositAll();
        const newBalanceLP = await erc20LP.balanceOf(accountAddr);

        expect(newBalanceLP.toString()).to.equal("0");
      }

      oneWeekLater = oneWeekLater + 1000 * oneWeekSeconds;
      await ethers.provider.send("evm_mine", [oneWeekLater]);
      await strategyOtherPairCometh.harvest();

      for (let i = 0; i < 3; i++) {
        const account = accounts[i];
        const accountAddr = accounts[i].address;

        await genericVault.connect(account).withdrawAll();
        const newBalanceLP = await erc20LP.balanceOf(accountAddr);

        expect(newBalanceLP > balancesLP[i]);
      }

      // Check fee collector balances
      const balanceLuchaDao = await await erc20C.balanceOf(daoTreasury);
      const balanceDevWallet = await await erc20C.balanceOf(devWallet);
      const balanceRewardWallet = await await erc20C.balanceOf(rewardWallet);
      expect(balanceLuchaDao === balanceDevWallet.mul(2));
      expect(balanceDevWallet === balanceRewardWallet);
    }
  ).timeout(1000000);
});
