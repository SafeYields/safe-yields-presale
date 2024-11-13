// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OrderType, Strategy } from "../types/StrategyControllerTypes.sol";
import { IStrategyFundManager } from "./IStrategyFundManager.sol";

interface IStrategyController {
    /**
     * @notice Open a new trading strategy
     * @param strategyHandler The address of the strategy handler contract
     * @param market The address of the market to trade
     * @param amount The amount of tokens to fund the strategy with
     * @param isLong Whether the strategy is long or short
     * @param orderType The type of order to place
     * @param exchangeData Additional data required by the strategy handler
     */
    function openStrategy(
        address strategyHandler,
        address market,
        uint256 amount,
        bool isLong,
        OrderType orderType,
        bytes memory exchangeData
    ) external payable;

    /**
     * @notice Open a new trading strategy on a centralized exchange (CEX)
     * @param cexType The type of CEX operation
     * @param trader The address of the trader
     * @param amount The amount of tokens to fund the strategy with
     */
    function openStrategyCEX(
        uint256 cexType,
        address trader,
        uint256 amount
    ) external payable;

    /**
     * @notice Update an existing trading strategy
     * @param strategyHandler The address of the strategy handler contract
     * @param strategyId The ID of the strategy to update
     * @param triggerPrice The new trigger price for the strategy
     * @param exchangeData Additional data required by the strategy handler
     */
    function updateStrategy(
        address strategyHandler,
        uint128 strategyId,
        uint256 triggerPrice,
        bytes memory exchangeData
    ) external payable;

    /**
     * @notice Exit an existing trading strategy
     * @param strategyHandler The address of the strategy handler contract
     * @param strategyId The ID of the strategy to exit
     * @param exchangeData Additional data required by the strategy handler
     */
    function exitStrategy(
        address strategyHandler,
        uint128 strategyId,
        bytes memory exchangeData
    ) external payable;

    /**
     * @notice Exit an existing trading strategy on a centralized exchange (CEX)
     * @param trader The address of the trader
     * @param strategyId The ID of the strategy to exit
     * @param amount The amount of tokens to return
     * @param pnl The profit or loss of the strategy
     */
    function exitStrategyCEX(
        address trader,
        uint128 strategyId,
        uint256 amount,
        int256 pnl
    ) external payable;

    /**
     * @notice Cancel an existing trading strategy
     * @param strategyHandler The address of the strategy handler contract
     * @param exchangeData Additional data required by the strategy handler
     */
    function cancelStrategy(
        address strategyHandler,
        bytes memory exchangeData
    ) external payable;

    /**
     * @notice Confirm the exit of a trading strategy
     * @param strategyHandler The address of the strategy handler contract
     * @param strategyId The ID of the strategy to confirm exit for
     * @param positionKey The key of the position to confirm exit for
     */
    function confirmExitStrategy(
        address strategyHandler,
        uint128 strategyId,
        bytes32 positionKey
    ) external;

    /**
     * @notice Add a new strategy handler to the controller
     * @param strategyHandler The address of the new strategy handler contract
     */
    function addStrategyHandler(
        address strategyHandler
    ) external;

    /**
     * @notice Remove a strategy handler from the controller
     * @param strategyHandler The address of the strategy handler contract to remove
     */
    function removeStrategyHandler(
        address strategyHandler
    ) external;

    /**
     * @notice Get the list of all registered strategy handlers
     * @return The array of strategy handler addresses
     */
    function getStrategyHandlers() external view returns (address[] memory);

    /**
     * @notice Get the details of a specific strategy
     * @param strategyId The ID of the strategy to retrieve
     * @return The strategy details
     */
    function getStrategy(
        uint256 strategyId
    ) external view returns (Strategy memory);

    /**
     * @notice Get the details of all strategies
     * @return The array of all strategy details
     */
    function getAllStrategies() external view returns (Strategy[] memory);
}