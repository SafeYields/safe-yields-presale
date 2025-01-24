//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OrderType, Strategy } from "../types/StrategyControllerTypes.sol";
import { IStrategyFundManager } from "./IStrategyFundManager.sol";

interface IStrategyController {
    function executeStrategy(address strategyHandler, uint256 amount) external;

    function openStrategy(
        address strategyHandler,
        address market,
        uint256 amount,
        uint256 executionFee,
        bool isLong,
        OrderType orderType,
        bytes memory exchangeData
    ) external payable;

    function closeStrategy(uint256 strategyId) external;

    function updateStrategy(
        address strategyHandler,
        uint256 strategyId,
        uint256 amountUpdate,
        uint256 slUpdate,
        uint256 tpUpdate,
        uint256 leverageUpdate
    ) external;

    function exitStrategy(address strategyHandler, uint128 strategyId, bytes memory exchangeData) external payable;

    function strategyCount() external view returns (uint128);

    function getAllStrategies() external view returns (Strategy[] memory allStrategies);

    function strategyCounts(address strategyHandler, uint256 index) external view returns (uint128);

    function getStrategyHandler(uint256 index) external view returns (address);

    function addStrategyHandler(address strategyHandler) external;

    function removeStrategyHandler(address strategyHandler) external;

    function getStrategyHandlers() external view returns (address[] memory);

    function getStrategyHandler() external view returns (address);

    function getStrategy(uint256 strategyId) external view returns (Strategy memory);

    function fundManager() external view returns (IStrategyFundManager);
}
