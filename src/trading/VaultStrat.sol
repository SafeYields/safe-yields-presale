// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { console, console2 } from "forge-std/Test.sol";

contract VaultStrategy {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;
    using Math for int128;

    struct UserDepositStats {
        uint48 lastDepositTimestamp;
        uint128 amountUnutilized;
        uint128 amountUtilized;
    }

    struct StrategyStats {
        uint48 timestampOfStrategy;
        uint256 amountRequested;
        uint256 lastAmountAvailable;
        int256 pnl;
    }

    mapping(address user => UserDepositStats userStats) public userStats;
    mapping(uint8 strategyID => StrategyStats strats) public strategies;
    mapping(address user => mapping(uint8 strategyID => uint128 userAmountUtilized)) public userUtilizations;

    StrategyStats[] public numberStrategies;

    uint256 public totalAmountsDeposited;

    function deposit(uint128 amount) external {
        if (userStats[msg.sender].lastDepositTimestamp != 0) {
            updateUserStats(msg.sender);
        }

        userStats[msg.sender].lastDepositTimestamp = uint48(block.timestamp);

        userStats[msg.sender].amountUnutilized += amount;

        totalAmountsDeposited += amount;
    }

    function executeTrade(uint128 amount) external {
        strategies[uint8(numberStrategies.length)] = StrategyStats({
            timestampOfStrategy: uint48(block.timestamp),
            amountRequested: amount,
            lastAmountAvailable: (totalAmountsDeposited),
            pnl: 0
        });

        console.log("Last Amount Available", totalAmountsDeposited);

        totalAmountsDeposited -= amount;

        numberStrategies.push(strategies[uint8(numberStrategies.length)]);
    }

    function endTrade(uint8 tradeId, int256 pnl) external {
        strategies[tradeId].pnl = pnl;
        if (pnl < 0) {
            totalAmountsDeposited += (strategies[tradeId].amountRequested - uint256(-pnl));
        } else {
            totalAmountsDeposited += strategies[tradeId].amountRequested;
        }
    }

    function claimPnl() external returns (int256 pnl) {
        updateUserStats(msg.sender);
        pnl = calculatePNL(msg.sender);
    }

    function calculatePNL(address user) public view returns (int256 pendingPnl) {
        for (uint8 strategyId; strategyId < numberStrategies.length; strategyId++) {
            pendingPnl += (strategies[strategyId].pnl * int256(uint256(userUtilizations[user][strategyId])))
                / int256(strategies[strategyId].amountRequested);
        }
    }

    function getPNL(address user) public view returns (int256 pendingPnl) {
        UserDepositStats memory userDeposits = userStats[user];

        for (uint8 strategyId; strategyId < numberStrategies.length; strategyId++) {
            StrategyStats memory currentStrategy = strategies[strategyId];

            if (currentStrategy.timestampOfStrategy > userDeposits.lastDepositTimestamp) {
                uint256 userUtilizedInStrategy = (userDeposits.amountUnutilized * currentStrategy.amountRequested)
                    / currentStrategy.lastAmountAvailable;

                pendingPnl += (strategies[strategyId].pnl * int256(userUtilizedInStrategy))
                    / int256(strategies[strategyId].amountRequested);
            }
        }
    }

    function numberStrategiesActive() external view returns (StrategyStats[] memory strategiesActive) {
        return numberStrategies;
    }

    function activeUserStats(address user) external view returns (UserDepositStats memory userDeposits) {
        return userStats[user];
    }

    function userCurrentUtilizations(address user, uint8 strategyId)
        external
        view
        returns (uint128 amountUtilizedPerStrategy)
    {
        return userUtilizations[user][strategyId];
    }

    function updateUserStats(address user) internal {
        UserDepositStats storage userDeposits = userStats[user];

        for (uint8 strategyId; strategyId < numberStrategies.length; strategyId++) {
            StrategyStats memory currentStrategy = strategies[strategyId];

            if (currentStrategy.timestampOfStrategy > userDeposits.lastDepositTimestamp) {
                uint256 userUtilizedInStrategy = (userDeposits.amountUnutilized * currentStrategy.amountRequested)
                    / currentStrategy.lastAmountAvailable;
                console.log("Strategy ID", strategyId);
                console.log("Strategy Amount Requested", currentStrategy.amountRequested);
                console.log("User amount Utilized Before", userDeposits.amountUtilized);

                userDeposits.amountUtilized += uint128(userUtilizedInStrategy);
                userDeposits.amountUnutilized -= uint128(userUtilizedInStrategy);

                userUtilizations[user][strategyId] = uint128(userUtilizedInStrategy);

                console.log("User amount Utilized for Strategy", userUtilizedInStrategy);
                console.log("User amount Unutilized before next Strategy", userDeposits.amountUnutilized);
                console.log();

                if (userDeposits.amountUnutilized == 0) break;
            }
        }
    }
}
