// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OrderType, Strategy } from "./trading-types/StrategyControllerTypes.sol";

contract StrategyController {
    uint256 strategyCount;
    address[] public strategyHandlers;

    address public fundManager;

    mapping(uint256 strategyId => Strategy) public strategies;

    function openStrategy(address strategyHandler, uint256 amount) external {
        uint256 strategyId = ++strategyCount;
        strategies[strategyId] =
            Strategy(amount, 0, 0, 0, 0, 0, OrderType.LIMIT, address(0), strategyHandler, true, false);
    }

    function getStrategy(uint256 strategyId) external view returns (Strategy memory) {
        return strategies[strategyId];
    }
}
