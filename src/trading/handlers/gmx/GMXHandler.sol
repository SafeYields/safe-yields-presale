// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { CreateDepositParams, CreateWithdrawalParams, SetPricesParams, CreateOrderParams } from "./types/GMXTypes.sol";
import { BaseStrategyHandler } from "../Base/BaseStrategyHandler.sol";
import { IExchangeRouter } from "./interfaces/IExchangeRouter.sol";
import { IStrategyController } from "../../interfaces/IStrategyController.sol";

contract GMXHandler is BaseStrategyHandler {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS AND IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IExchangeRouter public immutable exchangeRouter;
    address public constant orderVault = address(0x16);
    address public constant depositVault = address(0x20);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OrderCreated(
        address indexed market, uint128 indexed controllerStrategyId, bytes32 indexed orderId, bytes32 gmxPositionKey
    );
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SY__HDL__INVALID_ADDRESS();
    error SY__HDL__ONLY_CONTROLLER();
    error SY_GMX_SL_CREATE_ORDER_FAILED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    constructor(address _exchangeRouter, address _usdc, address _controller, string memory _exchangeName)
        BaseStrategyHandler(_controller, _usdc, _exchangeName)
    {
        if (_exchangeRouter == address(0)) revert SY__HDL__INVALID_ADDRESS();

        exchangeRouter = IExchangeRouter(_exchangeRouter);
        usdcToken = IERC20(_usdc);
        strategyController = _controller;
    }

    function openStrategy(bytes memory handlerData, bytes memory exchangeData)
        external
        override
        onlyController(msg.sender)
    {
        (uint256 orderAmount, uint128 controllerStrategyId, address market, bool isLong) =
            abi.decode(handlerData, (uint256, uint128, address, bool));

        usdcToken.safeTransferFrom(
            address(IStrategyController(strategyController).fundManager()), depositVault, orderAmount
        );

        (bool status, bytes memory returnData) = address(exchangeRouter).call(exchangeData);

        if (!status) revert SY_GMX_SL_CREATE_ORDER_FAILED();

        bytes32 orderId = abi.decode(returnData, (bytes32));

        bytes32 positionKey = getGMXPositionKey(address(this), market, address(usdcToken), isLong);

        strategyPositionId[controllerStrategyId] = uint256(positionKey);

        emit OrderCreated(market, controllerStrategyId, orderId, positionKey);
    }

    function exitStrategy(bytes memory exchangeData) external override onlyController(msg.sender) {
        (bool status, bytes memory returnData) = address(exchangeRouter).call(exchangeData);

        //update state variable
    }
    /// @notice from GMX contracts

    function getGMXPositionKey(address account, address market, address collateralToken, bool isLong)
        public
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encode(account, market, collateralToken, isLong));
    }
    // function openStrategy(CreateOrderParams memory order, uint128 amount) external onlyController(msg.sender) {
    //     //transfer tokens to the OrderVault
    //     usdcToken.safeTransferFrom(strategyController, orderVault, amount);

    //     //call create order.addresses
    //     bytes32 key = exchangeRouter.openStrategy(order);

    //     //emit OrderCreated(OrderParams, key);
    // }

    // function createDeposit(CreateDepositParams memory depositParams, uint128 amount)
    //     external
    //     onlyController(msg.sender)
    // {
    //     //transfer tokens to the OrderVault
    //     usdcToken.safeTransferFrom(strategyController, depositVault, amount);

    //     // bytes32 key = exchangeRouter.createDeposit(deposit);

    //     // emit DepositCreated(deposit, key);
    // }

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

    // function cancelOrder(bytes32 key) external onlyController(msg.sender) {
    //     exchangeRouter.cancelOrder(key);
    // }

    // function cancelWithdrawal(bytes32 key) external onlyController(msg.sender) {
    //     exchangeRouter.cancelWithdrawal(key);
    // }

    // function cancelDeposit(bytes32 key) external onlyController(msg.sender) {
    //     exchangeRouter.cancelDeposit(key);
    // }

    function createWithdrawal(bytes memory data) public override onlyController(msg.sender) {
        //call create withdrawal
    }

    function cancelOrder(bytes memory data) public override onlyController(msg.sender) {
        //call cancel order
    }

    function cancelWithdrawal(bytes memory data) public override onlyController(msg.sender) {
        //call cancel withdrawal
    }

    function cancelDeposit(bytes memory data) public override onlyController(msg.sender) {
        //call cancel deposit
    }
}
