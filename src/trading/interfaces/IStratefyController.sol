//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OrderType, Strategy } from "../trading-types/StrategyControllerTypes.sol";

interface IStrategyController {
    function openStrategy(address strategyHandler, uint256 amount) external;

    function closeStrategy(uint256 strategyId) external;

    function updateStrategy(
        uint256 strategyId,
        uint256 amountUpdate,
        uint256 slUpdate,
        uint256 tpUpdate,
        uint256 leverageUpdate
    ) external;

    function addStrategyHandler(address strategyHandler) external;

    function removeStrategyHandler(address strategyHandler) external;

    // function getStrategyHandler(address strategyHandler) external view returns (Strategy memory);

    function getStrategyHandlers() external view returns (address[] memory);

    function getStrategy(uint256 strategyId) external view returns (Strategy memory);
}
