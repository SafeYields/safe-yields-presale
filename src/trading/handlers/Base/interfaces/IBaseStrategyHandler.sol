// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IBaseStrategyHandler {
    function exchangeName() external view returns (string memory);

    function strategyController() external view returns (address);

    function openStrategy(bytes memory handlerData, bytes memory exchangeData) external payable;

    function exitStrategy(uint128 controllerStrategyId, bytes memory exitStrategyData) external payable;

    function cancelOrder(bytes memory data) external;

    function getStrategyPositionId(uint128 controllerStrategyId)
        external
        view
        returns (uint256 id256, bytes32 idBytes32);
}
