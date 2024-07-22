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
    uint256 public executionFee;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event StrategyExited(uint128 indexed controllerStrategyId);
    event OrderCanceled(bytes indexed returnData);
    event OrderCreated(
        address indexed market, uint128 indexed controllerStrategyId, bytes32 indexed orderId, bytes32 gmxPositionKey
    );
    event StrategyModified(
        bytes32 indexed key,
        uint256 indexed sizeDeltaUsd,
        uint256 indexed acceptablePrice,
        uint256 triggerPrice,
        uint256 minOutputAmount,
        bool autoCancel
    );
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SY_HDL__INVALID_ADDRESS();
    error SY_HDL__CALL_FAILED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    constructor(address _exchangeRouter, address _usdc, address _controller, string memory _exchangeName)
        BaseStrategyHandler(_controller, _usdc, _exchangeName)
    {
        if (_exchangeRouter == address(0)) revert SY_HDL__INVALID_ADDRESS();

        exchangeRouter = IExchangeRouter(_exchangeRouter);
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
        onlyController(msg.sender)
    {
        (uint256 orderAmount, uint128 controllerStrategyId, address market, bool isLong) =
            abi.decode(handlerData, (uint256, uint128, address, bool));

        bytes[] memory multicallData = new bytes[](3);

        //call exchangeRouter sendWNT tokens to pay fee.
        bytes memory sendExFeeData = abi.encodeWithSelector(exchangeRouter.sendWnt.selector, orderVault, executionFee);

        //send collateral
        bytes memory sendCollateralData =
            abi.encodeWithSelector(exchangeRouter.sendTokens.selector, usdcToken, orderVault, orderAmount);

        //call multicall
        multicallData[0] = sendExFeeData;
        multicallData[1] = sendCollateralData;
        multicallData[2] = openStrategyData;

        bytes[] memory resultData = exchangeRouter.multicall(multicallData);

        bytes32 orderId = abi.decode(resultData[2], (bytes32));

        bytes32 positionKey = getGMXPositionKey(address(this), market, address(usdcToken), isLong);

        strategyPositionId[controllerStrategyId] = uint256(positionKey);

        emit OrderCreated(market, controllerStrategyId, orderId, positionKey);
    }

    /**
     * @notice Exits an existing strategy by sending necessary funds to the exchange router and performing the exit actions.
     * @dev This function is callable only by the controller.
     *      It sends WNT (wrapped native tokens) as an execution fee and then executes the exit strategy.
     * @param controllerStrategyId The ID of the strategy to exit.
     * @param exitStrategyData Encoded data specific to the strategy being exited, which will be used in the multicall.
     */
    function exitStrategy(uint128 controllerStrategyId, bytes memory exitStrategyData)
        external
        payable
        override
        onlyController(msg.sender)
    {
        bytes[] memory multicallData = new bytes[](2);

        //call exchangeRouter sendWNT tokens to pray fee.
        bytes memory sendExFeeData = abi.encodeWithSelector(exchangeRouter.sendWnt.selector, orderVault, executionFee);

        multicallData[0] = sendExFeeData;
        multicallData[1] = exitStrategyData;

        //call multicall
        exchangeRouter.multicall(multicallData);

        //update state variable
        delete  strategyPositionId[controllerStrategyId];

        //!@note Handle the profit and loss (PnL) for the strategy exit in the controller

        emit StrategyExited(controllerStrategyId);
    }

    function cancelOrder(bytes memory cancelOrderData) external payable override onlyController(msg.sender) {
        bytes memory returnData = _externalCall(cancelOrderData);

        emit OrderCanceled(returnData);
    }

    function modifyStrategy(bytes memory exchangeData) external payable override onlyController(msg.sender) {
        _externalCall(exchangeData);
    }

    function getGMXPositionKey(address account, address market, address collateralToken, bool isLong)
        public
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encode(account, market, collateralToken, isLong));
    }

    function _externalCall(bytes memory callData) internal returns (bytes memory) {
        (bool status, bytes memory returnData) = address(exchangeRouter).call(callData);

        if (!status) revert SY_HDL__CALL_FAILED();

        return returnData;
    }
}
