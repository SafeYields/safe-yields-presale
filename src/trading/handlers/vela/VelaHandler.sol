// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { BaseStrategyHandler } from "../Base/BaseStrategyHandler.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IPositionVault } from "./interfaces/IPositionVault.sol";

/**
 * @title GMXHandler
 * @dev Manages the opening, modification, and closing of trading strategies on the VELA exchange
 *  including order fulfillment and cancellations.
 * @author 0xm00k
 */
contract VelaHandler is BaseStrategyHandler {
    IVault public vault;
    IPositionVault public positionVault;

    constructor(address _vault, address _usdc, address _controller, address _fundManager, string memory _exchangeName)
        BaseStrategyHandler(_controller, _usdc, _fundManager, _exchangeName)
    { }

    function openStrategy(bytes memory handlerData, bytes memory openStrategyData)
        external
        payable
        override
        returns (bytes32)
    {
        (, uint128 controllerStrategyId,,) = abi.decode(handlerData, (uint256, uint128, address, bool));

        if (strategyPositionId[controllerStrategyId] != 0) revert SY_HDL__POSITION_EXIST();

        (bool success,) = address(vault).call(openStrategyData);

        if (!success) revert SY_HDL__CALL_FAILED();
    }

    //note change input.
    function confirmExitStrategy(bytes32 positionKey) external override onlyController(msg.sender) { }

    function confirmOrderFulfillment(uint128 controllerStrategyId, bytes32 positionKey)
        external
        onlyController(msg.sender)
    {
        //(Position memory, OrderInfo memory, ConfirmInfo memory) = positionVault.getPosition(_account, _indexToken, _isLong, _posId);
    }

    function cancelOrder(bytes memory cancelOrderData) external override {
        (bool success,) = address(vault).call(cancelOrderData);

        if (!success) revert SY_HDL__CALL_FAILED();
    }

    function modifyStrategy(bytes memory) external payable override { }

    function exitStrategy(uint128, bytes memory) external payable override { }

    function getStrategyPositionId(uint128 controllerStrategyId)
        external
        view
        override
        returns (uint256 id256, bytes32 idBytes32)
    { }
}
