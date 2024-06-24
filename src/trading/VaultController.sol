// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IVaultController } from "./interfaces/IVaultController.sol";
import { UserDepositStats, StrategyStats } from "../types/SafeTypes.sol";

contract VaultController is IVaultController {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    StrategyStats[] public numberStrategies;
    uint256 public totalAmountsDeposited;

    mapping(address user => UserDepositStats userStats) public userStats;
    mapping(uint16 strategyID => StrategyStats strats) public strategies;
    mapping(address user => mapping(uint16 strategyID => uint128 userAmountUtilized)) public userUtilizations;

    /**
     * @notice User deposits into controller
     *
     */
    function deposit(uint128 amount) external override {
        if (userStats[msg.sender].lastDepositTimestamp != 0) {
            updateUserStats(msg.sender);
        }

        userStats[msg.sender].lastDepositTimestamp = uint48(block.timestamp);

        userStats[msg.sender].amountUnutilized += amount;

        totalAmountsDeposited += amount;
    }

    function calculatePNL(address user) public view override returns (int256 pendingPnl) {
        UserDepositStats memory userDeposits = userStats[user];

        for (uint16 strategyId; strategyId < numberStrategies.length; strategyId++) {
            StrategyStats memory currentStrategy = strategies[strategyId];

            if (currentStrategy.timestampOfStrategy > userDeposits.lastDepositTimestamp) {
                uint256 userUtilizedInStrategy = (userDeposits.amountUnutilized * currentStrategy.amountRequested)
                    / currentStrategy.lastAmountAvailable;

                pendingPnl += (strategies[strategyId].pnl * int256(userUtilizedInStrategy))
                    / int256(strategies[strategyId].amountRequested);
            }
        }
    }

    function claimPnl() external override returns (int256 pnl) { }

    /**
     * @notice called by only a strategy to request for funds.
     * @dev update the necessary info for a strategy such as timestamp,
     * last total deposits available and amount requested.
     */
    function supplyFunds(uint16 strategyId, uint128 amount) external override { }

    function numberStrategiesActive() external view override returns (StrategyStats[] memory strategiesActive) { }

    function activeUserStats(address user) external view override returns (UserDepositStats memory userDeposits) { }

    function userCurrentUtilizations(address user, uint8 strategyId)
        external
        view
        override
        returns (uint128 amountUtilizedPerStrategy)
    { }

    function updateUserStats(address user) internal {
        UserDepositStats storage userDeposits = userStats[user];

        for (uint16 strategyId; strategyId < numberStrategies.length; strategyId++) {
            StrategyStats memory currentStrategy = strategies[strategyId];

            if (currentStrategy.timestampOfStrategy > userDeposits.lastDepositTimestamp) {
                uint256 userUtilizedInStrategy = (userDeposits.amountUnutilized * currentStrategy.amountRequested)
                    / currentStrategy.lastAmountAvailable;

                userDeposits.amountUtilized += uint128(userUtilizedInStrategy);
                userDeposits.amountUnutilized -= uint128(userUtilizedInStrategy);

                userUtilizations[user][strategyId] = uint128(userUtilizedInStrategy);

                if (userDeposits.amountUnutilized == 0) break;
            }
        }
    }
}
