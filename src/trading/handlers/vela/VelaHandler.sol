// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { BaseStrategyHandler } from "../Base/BaseStrategyHandler.sol";
import { IVault, OrderType } from "./interfaces/IVault.sol";
import { IPositionVault } from "./interfaces/IPositionVault.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console } from "forge-std/Test.sol";

/**
 * @title VelaHandler
 * @dev Manages the opening, modification, and closing of trading strategies on the VELA exchange
 *  including order fulfillment and cancellations.
 * @author 0xm00k
 */
contract VelaHandler is BaseStrategyHandler {
    IVault public vault;
    IPositionVault public positionVault;

    constructor(address _vault, address _usdc, address _controller, address _fundManager, string memory _exchangeName)
        BaseStrategyHandler(_controller, _usdc, _fundManager, _exchangeName)
    {
        vault = IVault(_vault);
    }

    function opStrats() public payable {
        uint256[] memory params = new uint256[](4);
        params[0] = 168331567680524983643408631905913;
        params[1] = 250;
        params[2] = 50000000000000000000000000000000;
        params[3] = 1325000000000000000000000000000000;

        bytes memory data = abi.encodeWithSignature(
            "newPositionOrder(uint256,bool,uint8,uint256[],address)", 8, true, OrderType.MARKET, params, address(0)
        );

        (bool success,) = payable(address(vault)).call(data);
    }

    function openStrategy(bytes memory handlerData, bytes memory openStrategyData)
        external
        payable
        override
        onlyController
        returns (bytes32)
    {
        (uint256 amount, uint128 controllerStrategyId,,) = abi.decode(handlerData, (uint256, uint128, address, bool));

        if (strategyPositionId[controllerStrategyId] != 0) revert SY_HDL__POSITION_EXIST();

        IERC20(usdcToken).approve(address(vault), amount);

        vault.deposit(address(this), address(usdcToken), amount);

        (bool success,) = address(vault).call(openStrategyData);

        if (!success) revert SY_HDL__CALL_FAILED();
        
    }

    //note change input.
    function confirmExitStrategy(bytes32 positionKey) external override onlyController { }

    function confirmOrderFulfillment(uint128 controllerStrategyId, bytes32 positionKey) external onlyController {
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

    fallback() external payable { }
}
