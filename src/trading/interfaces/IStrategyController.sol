//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OrderType, Strategy } from "../types/StrategyControllerTypes.sol";

interface IStrategyController {
    function executeStrategy(address strategyHandler, uint256 amount) external;

    function closeStrategy(uint256 strategyId) external;

    function updateStrategy(
        address strategyHandler,
        uint256 strategyId,
        uint256 amountUpdate,
        uint256 slUpdate,
        uint256 tpUpdate,
        uint256 leverageUpdate
    ) external;

    function strategyCount() external view returns (uint128);

    function strategyCounts(address strategyHandler, uint256 index) external view returns (uint128);

    function getStrategyHandler(uint256 index) external view returns (address);

    function addStrategyHandler(address strategyHandler) external;

    function removeStrategyHandler(address strategyHandler) external;

    function getStrategyHandlers() external view returns (address[] memory);

    function getStrategy(address strategyHandler, uint256 strategyId) external view returns (Strategy memory);
}
