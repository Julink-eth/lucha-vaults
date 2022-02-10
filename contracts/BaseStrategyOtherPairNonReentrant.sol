// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import {BaseStrategyStakingRewards} from "./BaseStrategyStakingRewards.sol";
import {IStakingMultiRewards} from "./interfaces/IStakingMultiRewards.sol";
import {IUniswapRouterV2} from "./interfaces/IUniswapRouterV2.sol";
import {IUsdcSwap} from "./interfaces/IUsdcSwap.sol";

abstract contract BaseStrategyOtherPairNonReentrant is
    BaseStrategyStakingRewards,
    KeeperCompatibleInterface
{
    struct FeeCollector {
        address collectorAddress;
        uint256 feeShare;
    }

    uint256 public constant KEEP_MAX = 10000;

    address public tokenA;
    address public tokenB;
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant MAI = 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1;

    address public constant ANCHOR = 0x947D711C25220d8301C087b25BA111FE8Cbf6672;
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    // Reward tokens
    address[] public rewardsTokens;

    //List of addresses that receive fees from the protocol
    FeeCollector[] public collectors;

    //For the chainlink keepers
    uint256 public interval;
    uint256 public lastHarvestTime;

    constructor(
        address _rewards,
        address _want,
        address _tokenA,
        address _tokenB,
        address _router
    ) BaseStrategyStakingRewards(_rewards, _want, _router) {
        tokenA = _tokenA;
        tokenB = _tokenB;

        rewardsTokens = IStakingMultiRewards(rewards).getRewardsTokens();

        // 4 hours interval by default for the harvest to be called
        interval = 14400;
        lastHarvestTime = block.timestamp;
    }

    // **** State Mutations ****

    //Add a new fee collector
    function addFeeCollector(address collectorAddress, uint256 collectorShare)
        public
        onlyOwner
    {
        FeeCollector memory collector = FeeCollector(
            collectorAddress,
            collectorShare
        );
        collectors.push(collector);
    }

    //Remove a fee collector
    function removeFeeCollector(address collectorAddress) public onlyOwner {
        for (uint256 i = 0; i < collectors.length; i++) {
            if (collectors[i].collectorAddress == collectorAddress) {
                collectors[i] = collectors[collectors.length - 1];
                collectors.pop();
                break;
            }
        }
    }

    //Set the interval for the chainlink keepers to do the up keep
    function setInterval(uint256 newInterval) external onlyOwner {
        interval = newInterval;
    }

    //deposit() needs to be called manually afterward because deposit() and getReward() have the nonReentrant modifier, so I cannot claim and deposit in the same tx
    function harvest() public override onlyHumanOrWhitelisted {
        //Update the time of harvest
        lastHarvestTime = block.timestamp;

        //Transfer any harvestedToken and WMATIC that may already be in the contract to the fee dist fund
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            address harvestedToken = rewardsTokens[i];

            uint256 leftOverBalance = IERC20(harvestedToken).balanceOf(
                address(this)
            );
            if (leftOverBalance > 0 && collectors.length > 0) {
                IERC20(harvestedToken).transfer(
                    collectors[0].collectorAddress,
                    leftOverBalance
                );
            }
        }

        uint256 wmaticBalance = IERC20(WMATIC).balanceOf(address(this));
        if (wmaticBalance > 0) {
            IERC20(WMATIC).transfer(
                collectors[0].collectorAddress,
                wmaticBalance
            );
        }

        _getReward();

        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            address harvestedToken = rewardsTokens[i];
            uint256 harvestedBalance = IERC20(harvestedToken).balanceOf(
                address(this)
            );

            //Distribute fee and convert rewards to LP tokens
            if (harvestedBalance > 0) {
                uint256 afterFeeAmount = harvestedBalance;
                for (uint256 j = 0; j < collectors.length; j++) {
                    uint256 feeAmount = (harvestedBalance *
                        collectors[j].feeShare) / KEEP_MAX;
                    afterFeeAmount = afterFeeAmount - feeAmount;
                    distributeFee(
                        collectors[j].collectorAddress,
                        harvestedToken,
                        feeAmount
                    );
                }

                if (harvestedToken != tokenA) {
                    //Special case for MAI token we use the anchor first
                    if (harvestedToken == MAI) {
                        IERC20(harvestedToken).approve(ANCHOR, afterFeeAmount);
                        IUsdcSwap(ANCHOR).swapTo(afterFeeAmount);
                        harvestedToken = USDC;
                        afterFeeAmount = IERC20(USDC).balanceOf(address(this));
                    }
                    _swapUniswapWithPath(
                        getPath(harvestedToken, tokenA),
                        afterFeeAmount
                    );
                }
            }
        }

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        if (balanceA > 0) {
            _swapUniswapWithPath(getPath(tokenA, tokenB), balanceA / 2);
        }

        //Add liquidity
        uint256 aBalance = IERC20(tokenA).balanceOf(address(this));
        uint256 bBalance = IERC20(tokenB).balanceOf(address(this));

        if (aBalance > 0 && bBalance > 0) {
            IERC20(tokenA).approve(currentRouter, 0);
            IERC20(tokenA).approve(currentRouter, aBalance);
            IERC20(tokenB).approve(currentRouter, 0);
            IERC20(tokenB).approve(currentRouter, bBalance);

            IUniswapRouterV2(currentRouter).addLiquidity(
                tokenA,
                tokenB,
                aBalance,
                bBalance,
                0,
                0,
                address(this),
                block.timestamp + 60
            );
        }

        //Stake the LPs
        deposit();
    }

    // **** Internal functions ****

    //Get the path to swap tokens on Polygon
    function getPath(address token1, address token2)
        private
        pure
        returns (address[] memory)
    {
        if (token1 != WMATIC && token2 != WMATIC) {
            address[] memory pathWMATIC = new address[](3);
            pathWMATIC[0] = token1;
            pathWMATIC[1] = WMATIC;
            pathWMATIC[2] = token2;
            return pathWMATIC;
        }

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;

        return path;
    }

    //Send the fees to the fee dist
    function distributeFee(
        address recipient,
        address feeToken,
        uint256 feeAmount
    ) internal {
        if (feeAmount > 0) {
            IERC20(feeToken).transfer(recipient, feeAmount);
        }
    }

    // **** Chainlink keepers functions ****

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = (block.timestamp - lastHarvestTime) > interval;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        if ((block.timestamp - lastHarvestTime) > interval) {
            harvest();
        }
    }
}
