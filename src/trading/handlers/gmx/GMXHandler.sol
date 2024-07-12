// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { CreateDepositParams, CreateWithdrawalParams, SetPricesParams, CreateOrderParams } from
//UpdateOrderParams
"./types/GMXTypes.sol";

import { IExchangeRouter } from "./interfaces/IExchangeRouter.sol";

contract GMXHandler is Ownable2Step {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS AND IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IExchangeRouter public immutable exchangeRouter;
    address public constant orderVault = address(0x16);
    address public constant depositVault = address(0x20);
    //note add mapping to track strategies , needed??

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public usdc;
    address public controller;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OrderCreated(CreateOrderParams indexed OrderParams);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SY__HDL__INVALID_ADDRESS();
    error SY__HDL__ONLY_CONTROLLER();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyController(address _caller) {
        if (_caller != address(controller)) revert SY__HDL__ONLY_CONTROLLER();
        _;
    }

    constructor(address _exchangeRouter, address protocolAdmin, address _usdc, address _controller)
        Ownable(protocolAdmin)
    {
        if (
            _exchangeRouter == address(0) || protocolAdmin == address(0) || _usdc == address(0)
                || _controller == address(0)
        ) {
            revert SY__HDL__INVALID_ADDRESS();
        }

        exchangeRouter = IExchangeRouter(_exchangeRouter);
        usdc = IERC20(_usdc);
        controller = _controller;
    }

    function createOrder(CreateOrderParams memory order, uint128 amount) external onlyController(msg.sender) {
        //transfer tokens to the OrderVault
        usdc.safeTransferFrom(controller, orderVault, amount);

        //call create order.addresses
        bytes32 key = exchangeRouter.createOrder(order);

        //emit OrderCreated(OrderParams, key);
    }

    function createDeposit(CreateDepositParams memory depositParams, uint128 amount)
        external
        onlyController(msg.sender)
    {
        //transfer tokens to the OrderVault
        usdc.safeTransferFrom(controller, depositVault, amount);

        // bytes32 key = exchangeRouter.createDeposit(deposit);

        // emit DepositCreated(deposit, key);
    }

    function createWithdrawal(CreateWithdrawalParams memory withdrawParams) external onlyController(msg.sender) {
        //bytes32 key = exchangeRouter.createWithdrawal(withdraw);

        // emit WithdrawalCreated(withdrawParams, key);
    }

    // function updateOrder(UpdateOrderParams memory updateOrderParams) external onlyController(msg.sender) {
    //     exchangeRouter.updateOrder(
    //         updateOrderParams.key,
    //         updateOrderParams.sizeDeltaUsd,
    //         updateOrderParams.acceptablePrice,
    //         updateOrderParams.triggerPrice,
    //         updateOrderParams.minOutputAmount,
    //         updateOrderParams.autoCancel
    //     );

    //     emit OrderUpdated(updateOrderParams);
    // }

    function cancelOrder(bytes32 key) external onlyController(msg.sender) {
        exchangeRouter.cancelOrder(key);
    }

    function cancelWithdrawal(bytes32 key) external onlyController(msg.sender) {
        exchangeRouter.cancelWithdrawal(key);
    }

    function cancelDeposit(bytes32 key) external onlyController(msg.sender) {
        exchangeRouter.cancelDeposit(key);
    }
}
