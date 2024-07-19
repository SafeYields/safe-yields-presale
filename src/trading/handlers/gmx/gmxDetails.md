## GMX Details

### Create Order/Decrease Position

- create params off-chain
- Acceptable Price : The worst price at which the order will be executed
- Trigger Price: The price at which the stop-loss order is activated
- Multicall to send execution fee, sendTokens to OrderVault and create Order.
- Order Type Market,Limit

### Cancel Order

- create params off-chain
- `Use this to get Order`
  `await this.reader.getOrder(this.DATASTORE_ADDR, od.orderId)`
- Use multicall to call cancelOrder

### Update Order.

- create params off-chain
- You can only Update Limit Orders.(no market Orders). so LIMIT increase or Decrease.
- Use the multicall to call update.

### Close Position

#### Conditions to close position

// if market:
// create opposite market decrease order of that
// if stop loss:
// limit / trigger order at given price in negative direction
// if take profit
// limit / trigger order at given price in positive direction

- create params off-chain
- InitialCollateral = 0
- size to close is given
- decreasePositionSwapType: DecreasePositionSwapType.SwapPnlTokenToCollateralToken.
  Example Close Order Params:
  ` let orderTx = await this.exchangeRouter.populateTransaction.createOrder({
  addresses: {
    receiver: wallet,
    callbackContract: ethers.constants.AddressZero,
    uiFeeReceiver: ethers.constants.AddressZero,
    market: positionInfo[i].marketId.split('-')[2],
    initialCollateralToken: positionInfo[i].collateral.address[42161]!,
    swapPath: []
  },
  numbers: {
    sizeDeltaUsd: sizeToClose,
    initialCollateralDeltaAmount: ZERO,
    triggerPrice: triggerPrice,
    acceptablePrice: acceptablePrice,
    executionFee: DEFAULT_EXECUTION_FEE,
    callbackGasLimit: ethers.constants.Zero,
    minOutputAmount: ethers.constants.Zero
  },
  orderType: orderType,
  decreasePositionSwapType: DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
  isLong: positionInfo[i].direction == 'LONG',
  shouldUnwrapNativeToken: closePositionData[i].outputCollateral!.symbol !== 'WETH',
  referralCode: REFERRAL_CODE
})`
