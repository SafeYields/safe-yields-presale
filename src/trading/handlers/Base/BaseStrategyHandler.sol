//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

abstract contract BaseStrategyHandler {
    string public exchangeName;
    address public strategyController;
    uint256 public strategyHandlerId;

    constructor(address _strategyController, string memory _exchangeName) {
        strategyController = _strategyController;
        exchangeName = _exchangeName;
    }
}
/**
 * controller opens strats so should assign strategyIds
 * Strategy data should be stored in handler instead of controller?
 */
