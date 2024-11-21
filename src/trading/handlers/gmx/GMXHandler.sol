// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GMXOrderType } from "./types/GMXTypes.sol";
import { BaseStrategyHandler } from "../Base/BaseStrategyHandler.sol";
import { IExchangeRouter } from "./interfaces/IExchangeRouter.sol";
import { IReader } from "./interfaces/IReader.sol";
import { PositionProps } from "./types/PositionTypes.sol";
import { OrderProps } from "./types/OrderTypes.sol";
import { console } from "forge-std/Test.sol";

/**
 * @title GMXHandler
 * @dev Manages the opening, modification, and closing of trading strategies on the GMX exchange
 *  including order fulfillment and cancellations.
 * @author 0xm00k
 */
contract GMXHandler is BaseStrategyHandler {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS AND IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IExchangeRouter public immutable exchangeRouter;
    IReader public immutable gmxReader;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public orderVault;
    address public dataStore;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event DataStoreUpdated(address indexed oldDataStore, address indexed newDataStore);
    event OrderVaultUpdated(address indexed oldOrderVault, address indexed newOrderVault);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SY_HDL__INVALID_ADDRESS();
    error SY_HDL__ORDER_NOT_SETTLED();
    error SY_HDL__NO_ORDER();
    error SY_HDL__NOT_LIMIT_ORDER();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _exchangeRouter,
        address _usdc,
        address _controller,
        address _fundManager,
        address _reader,
        address _orderVault,
        address _dataStore,
        string memory _exchangeName
    ) BaseStrategyHandler(_controller, _usdc, _fundManager, _exchangeName) {
        if (
            _exchangeRouter == address(0) || _reader == address(0) || _orderVault == address(0)
                || _dataStore == address(0)
        ) revert SY_HDL__INVALID_ADDRESS();

        exchangeRouter = IExchangeRouter(_exchangeRouter);

        orderVault = _orderVault;
        dataStore = _dataStore;

        gmxReader = IReader(_reader);
    }

    /**
     * @notice Opens a new strategy by sending necessary funds and data to the exchange router.
     * @dev This function is callable only by the controller.
     *      It sends WNT (wrapped native tokens) as an execution fee, sends USDC as collateral, and then executes the strategy.
     * @param handlerData Encoded data containing the order amount, controller strategy ID, market address, and whether the strategy is long.
     * @param openStrategyData Encoded data specific to the strategy being opened, which will be used in the multicall.
     */
    function openStrategy(bytes memory handlerData, bytes memory openStrategyData)
        external
        payable
        override
        onlyController
        returns (bytes32 orderId)
    {
        (uint256 orderAmount, uint256 executionFee, uint128 controllerStrategyId,,) =
            abi.decode(handlerData, (uint256, uint256, uint128, address, bool));

        if (strategyPositionId[controllerStrategyId] != 0) revert SY_HDL__POSITION_EXIST();

        bytes[] memory multicallData = new bytes[](3);

        //call exchangeRouter sendWNT tokens to pay fee.
        bytes memory sendExecutionFeeData =
            abi.encodeWithSelector(exchangeRouter.sendWnt.selector, orderVault, executionFee);

        //send collateral
        bytes memory sendCollateralData =
            abi.encodeWithSelector(exchangeRouter.sendTokens.selector, usdcToken, orderVault, orderAmount);

        multicallData[0] = sendExecutionFeeData;
        multicallData[1] = sendCollateralData;
        multicallData[2] = openStrategyData;

        //! remove address
        IERC20(usdcToken).approve(0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6, orderAmount);

        bytes[] memory resultData = exchangeRouter.multicall{ value: executionFee }(multicallData);

        orderId = abi.decode(resultData[2], (bytes32));
    }

    /// @notice Exits a strategy by executing a series of operations on the GMX exchange router.
    /// @param executionFee The fee required for executing the exit strategy.
    /// @param exitStrategyData Encoded data containing the details of the exit strategy.
    /// @dev This function prepares a multicall data array to first send the execution fee
    ///      and then perform the exit strategy operations. It then calls the `multicall` function
    ///      on the `exchangeRouter`.
    function exitStrategy(uint256 executionFee, bytes memory exitStrategyData) external payable onlyController {
        bytes[] memory multicallData = new bytes[](2);

        //call exchangeRouter sendWNT tokens to pay fee.
        bytes memory sendExFeeData = abi.encodeWithSelector(exchangeRouter.sendWnt.selector, orderVault, executionFee);

        multicallData[0] = sendExFeeData;
        multicallData[1] = exitStrategyData;

        //call multicall
        exchangeRouter.multicall(multicallData);
    }

    function confirmExitStrategy(bytes32 positionKey) external view onlyController {
        PositionProps memory position = gmxReader.getPosition(dataStore, positionKey);

        if (position.addresses.account != address(0)) revert SY_HDL__ORDER_NOT_SETTLED();
    }

    /// @notice Confirms the fulfillment of an order by verifying the position on the GMX exchange.
    /// @param controllerStrategyId The ID of the strategy in the controller.
    /// @param positionKey The key of the position to be confirmed.
    /// @dev This function retrieves the position details using the `positionKey`, checks if the position
    ///      is settled.
    function confirmOrderFulfillment(uint128 controllerStrategyId, bytes32 positionKey) external /*onlyController*/ {
        PositionProps memory position = gmxReader.getPosition(dataStore, positionKey);

        if (position.addresses.account == address(0)) revert SY_HDL__ORDER_NOT_SETTLED();

        strategyPositionId[controllerStrategyId] = uint256(positionKey);

        strategyCounts++;
    }

    /// @notice Cancels an existing order on the GMX exchange router.
    /// @param cancelOrderData Encoded data containing the order ID to be canceled.
    /// @dev This function decodes the `cancelOrderData` to extract the `orderId`, checks if the order exists,
    ///      and then calls the `cancelOrder` function on the `exchangeRouter'.
    function cancelOrder(bytes memory cancelOrderData) external override {
        (bool success,) = address(exchangeRouter).call(cancelOrderData);

        if (!success) revert SY_HDL__CALL_FAILED();
    }

    /// @notice Modifies an existing strategy order on the GMX exchange router.
    /// @param exchangeDataParams Encoded data containing the order details to be modified.
    /// - orderId: The ID of the order to be modified.
    /// - acceptablePrice: The acceptable price for the order.
    /// - triggerPrice: The price at which the order will be triggered.
    /// @dev This function decodes the `exchangeData`, checks if the order exists and is a limit order,
    ///      and then calls the `updateOrder` function on the `exchangeRouter`.
    function modifyStrategy(bytes memory exchangeDataParams) external payable override onlyController {
        (
            bytes32 orderKey,
            uint256 sizeDeltaUsd,
            uint256 acceptablePrice,
            uint256 triggerPrice,
            uint256 minOutputAmount,
            bool autoCancel
        ) = abi.decode(exchangeDataParams, (bytes32, uint256, uint256, uint256, uint256, bool));

        console.logBytes32(orderKey);
        console.log("Size", sizeDeltaUsd);

        OrderProps memory order = gmxReader.getOrder(dataStore, orderKey);

        console.log(order.addresses.account);

        if (!checkOrderExist(order)) revert SY_HDL__NO_ORDER();

        if (
            uint256(order.numbers.orderType) == uint256(GMXOrderType.MarketIncrease)
                || uint256(order.numbers.orderType) == uint256(GMXOrderType.MarketDecrease)
        ) {
            revert SY_HDL__NOT_LIMIT_ORDER();
        }

        exchangeRouter.updateOrder(orderKey, sizeDeltaUsd, acceptablePrice, triggerPrice, minOutputAmount, autoCancel);
    }

    //!add ownable
    function setOrderVault(address newOrderVault) external {
        address oldOrderVault = orderVault;

        orderVault = newOrderVault;

        emit OrderVaultUpdated(oldOrderVault, newOrderVault);
    }

    function setDataStore(address newDataStore) external {
        address oldDataStore = dataStore;

        orderVault = newDataStore;

        emit DataStoreUpdated(oldDataStore, newDataStore);
    }

    function getGMXPositionKey(address account, address market, address collateralToken, bool isLong)
        public
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encode(account, market, collateralToken, isLong));
    }

    function checkOrderExist(OrderProps memory _order) internal pure returns (bool) {
        return _order.addresses.account != address(0);
    }

    fallback() external payable { }

    receive() external payable { }
}
