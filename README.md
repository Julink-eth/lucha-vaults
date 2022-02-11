This project has been built to create auto compounded vaults for the Luchadores ecosystem : https://luchadores.io/
You need hardhat and NodeJs installed, so you need to install hardhat to test/deploy the contracts.
You'll also have to add a .env file with your own keys, the .env.example contains the keys that needs be replaced with your own.

# Smart contract addresses already deployed

Cometh Farm WMATIC/LUCHA  
-Strategy : 0x8e9d261FB991935917cbcb0945168908461419A7  
-Vault : 0x9C59E595CbA741DfCd4C66743652afFfB059c258

Cometh Farm MUST/LUCHA  
-Strategy : 0x6C57Bc7eEC2144Eb9ab6509556051E1fF6D1C024  
-Vault : 0xE50bc19B7508fd4e0B5E6f9513bB9bfdD04339e3

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

# Interact with the vault

## Deposit and withdraw

A user will need to deposit its LP tokens to the vault contract.
Once the LP tokens have been approved you can call either :

```solidity
function deposit(uint256 _amount)

depositAll()
```

Once the LP tokens have been deposited, they are automatically transferred to the vault's strategy and staked in the staking reward contract.
You can check the balance of the staked token for a user using the formula (Using the BigNumber web3 library) :

```javascript
let userLPStaked = vaultContract
    .getRatio()
    .times(vaultContract.getTokensStaked(userAddr))
    .div(1e18);
```

To withdraw the LP tokens you have to use :

```solidity
function withdrawAll()
```

## Harvest to compound the interest generated

The generated interests can be auto compounded into more LPs for the vault thanks to the function in the strategy contract :

```solidity
function harvest()
```

Anyone can call this function but it will be called periodically by the Chainlink keepers to make sure those interests are compounded.
