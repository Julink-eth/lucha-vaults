This project has been built to create auto compounded vaults for the Luchadores ecosystem : https://luchadores.io/
You need hardhat and NodeJs installed, so you need to install hardhat to test/deploy the contracts.
You'll also have to add a .env file with your own keys, the .env.example contains the keys that needs be replaced with your own.

# Test the contracts

A couple tests have been written to test the contracts you can write your own.
In the command line at the root level of the project type :

```shell
npm install
npx hardhat test
```

# Deploy a new vault/strategy pair

You first have to deploy the vault and strategy deployers : `VaultDeployer.sol` and `StrategyDeployerCometh`
The code is made for Pools on the cometh dex but can be easily modified to adapt to any dexes that is a UniswapV2 fork.

Deploy the strategy first, you can use the script in scripts/deploy.ts.
You can change the parameters of the strategy you want to create at the line :

```javascript
let deployTx = await strategyDeployerCometh.deploy(
    stakingContract,
    lpContract,
    tokenA,
    tokenB,
    pairName,
    vaultDeployer.address
);
```

Once you have the right parameters you can type the command in the terminal :

```shell
npx hardhat run scripts/deploy.ts --network matic
```

This will deploy the strategy and vault deployers and create a strategy and a vault from those deployers right after.
