// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

// @dev CreateDepositParams struct used in createDeposit to avoid stack

struct CreateDepositParams {
    address receiver; // @param receiver the address to send the market tokens to
    address callbackContract; // @param callbackContract the callback contract
    address uiFeeReceiver; // @param uiFeeReceiver the ui fee receiver
    address market; // @param market the market to deposit into
    address initialLongToken; // @param minMarketTokens the minimum acceptable number of liquidity tokens
    address initialShortToken; // @param shouldUnwrapNativeToken whether to unwrap the native token when
    address[] longTokenSwapPath; // sending funds back to the user in case the deposit gets cancelled
    address[] shortTokenSwapPath; // @param executionFee the execution fee for keepers
    uint256 minMarketTokens; // @param callbackGasLimit the gas limit for the callbackContract
    /**
     * @dev specifies whether to unwrap the native token, e.g. if the deposit is cancelled and
     *  the initialLongToken token is WETH, setting this to true would convert the WETH
     *  token to ETH before it is refunded
     */
    bool shouldUnwrapNativeToken;
    /**
     * @dev The amount of native token that is included for the execution fee,
     *  e.g. on Arbitrum this would be ETH, this is the maximum execution fee
     *  that keepers can use to execute the deposit. When the deposit is executed,
     *  any excess execution fee is sent back to the deposit's account.
     */
    uint256 executionFee;
    /**
     * The gas limit to be passed to the callback contract on withdrawal execution / cancellationLimit:
     *  The gas limit to be passed to the callback contract on withdrawal execution / cancellation
     */
    uint256 callbackGasLimit;
}

/**
 * @param receiver The address that will receive the withdrawal tokens.
 * @param callbackContract The contract that will be called back.
 * @param market The market on which the withdrawal will be executed.
 * @param minLongTokenAmount The minimum amount of long tokens that must be withdrawn.
 * @param minShortTokenAmount The minimum amount of short tokens that must be withdrawn.
 * @param shouldUnwrapNativeToken Whether the native token should be unwrapped when executing the withdrawal.
 * @param executionFee The execution fee for the withdrawal.
 * @param callbackGasLimit The gas limit for calling the callback contract.
 */
struct CreateWithdrawalParams {
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
    uint256 minLongTokenAmount;
    uint256 minShortTokenAmount;
    bool shouldUnwrapNativeToken;
    uint256 executionFee;
    uint256 callbackGasLimit;
}

// @dev CreateOrderParams struct used in createOrder to avoid stack
// too deep errors
//
// @param addresses address values
// @param numbers number values
// @param orderType for order.orderType
// @param decreasePositionSwapType for order.decreasePositionSwapType
// @param isLong for order.isLong
// @param shouldUnwrapNativeToken for order.shouldUnwrapNativeToken
struct CreateOrderParams {
    CreateOrderParamsAddresses addresses;
    CreateOrderParamsNumbers numbers;
    OrderType orderType;
    DecreasePositionSwapType decreasePositionSwapType;
    bool isLong;
    bool shouldUnwrapNativeToken;
    bool autoCancel;
    bytes32 referralCode;
}

enum DecreasePositionSwapType {
    NoSwap,
    SwapPnlTokenToCollateralToken,
    SwapCollateralTokenToPnlToken
}

enum OrderType {
    // @dev MarketSwap: swap token A to token B at the current market price
    // the order will be cancelled if the minOutputAmount cannot be fulfilled
    MarketSwap,
    // @dev LimitSwap: swap token A to token B if the minOutputAmount can be fulfilled
    LimitSwap,
    // @dev MarketIncrease: increase position at the current market price
    // the order will be cancelled if the position cannot be increased at the acceptablePrice
    MarketIncrease,
    // @dev LimitIncrease: increase position if the triggerPrice is reached and the acceptablePrice can be fulfilled
    LimitIncrease,
    // @dev MarketDecrease: decrease position at the current market price
    // the order will be cancelled if the position cannot be decreased at the acceptablePrice
    MarketDecrease,
    // @dev LimitDecrease: decrease position if the triggerPrice is reached and the acceptablePrice can be fulfilled
    LimitDecrease,
    // @dev StopLossDecrease: decrease position if the triggerPrice is reached and the acceptablePrice can be fulfilled
    StopLossDecrease,
    // @dev Liquidation: allows liquidation of positions if the criteria for liquidation are met
    Liquidation
}

struct CreateOrderParamsNumbers {
    uint256 sizeDeltaUsd;
    uint256 initialCollateralDeltaAmount;
    uint256 triggerPrice;
    uint256 acceptablePrice;
    uint256 executionFee;
    uint256 callbackGasLimit;
    uint256 minOutputAmount;
}

struct CreateOrderParamsAddresses {
    address receiver;
    address cancellationReceiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address initialCollateralToken;
    address[] swapPath;
}

struct SetPricesParams {
    address[] tokens;
    address[] providers;
    bytes[] data;
}

//UpdateOrderParams
