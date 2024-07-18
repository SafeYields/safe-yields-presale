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

    error SY__HDL__INVALID_ADDRESS();
    error SY__HDL__ONLY_CONTROLLER();
    error SY_CALL_FAILED();
    error SY_GMX_SL_MODIFY_STRATEGY_FAILED();

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

        if (!status) revert SY_CALL_FAILED();

        bytes32 orderId = abi.decode(returnData, (bytes32));

        bytes32 positionKey = getGMXPositionKey(address(this), market, address(usdcToken), isLong);

        strategyPositionId[controllerStrategyId] = uint256(positionKey);

        emit OrderCreated(market, controllerStrategyId, orderId, positionKey);
    }

    function exitStrategy(bytes memory exchangeData) external override onlyController(msg.sender) {
        (bool status, bytes memory returnData) = address(exchangeRouter).call(exchangeData);

        if (!status) revert SY_CALL_FAILED();

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

    //!note: depositing or withdrawing
    function modifyStrategy(bytes memory exchangeData) external override onlyController(msg.sender) {
        bytes32 key;
        uint256 sizeDeltaUsd;
        uint256 acceptablePrice;
        uint256 triggerPrice;
        uint256 minOutputAmount;
        bool autoCancel;

        assembly {
            // Skip the first 4 bytes (function selector)
            key := mload(add(exchangeData, 4))
            sizeDeltaUsd := mload(add(exchangeData, 36))
            acceptablePrice := mload(add(exchangeData, 68))
            triggerPrice := mload(add(exchangeData, 100))
            minOutputAmount := mload(add(exchangeData, 132))
            autoCancel := mload(add(exchangeData, 164))
        }

        (bool status,) = address(exchangeRouter).call(exchangeData);

        if (!status) revert SY_CALL_FAILED();

        //update state variables

        emit StrategyModified(key, sizeDeltaUsd, acceptablePrice, triggerPrice, minOutputAmount, autoCancel);
    }
}
