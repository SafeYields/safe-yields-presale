// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { CreateDepositParams, CreateWithdrawalParams, SetPricesParams, CreateOrderParams } from "../types/GMXTypes.sol";

interface IExchangeRouter {
    /**
     *  @dev To create a deposit, tokens need to first be transferred to the DepositVault
     *  ExchangeRouter.createDeposit can then be called after. The transfer of tokens
     *  and the calling of ExchangeRouter.createDeposit should be done in a single transaction.
     */
    function createDeposit(CreateDepositParams calldata params) external payable returns (bytes32);

    function cancelDeposit(bytes32 key) external payable;

    function createWithdrawal(CreateWithdrawalParams calldata params) external payable returns (bytes32);

    function cancelWithdrawal(bytes32 key) external payable;

    /**
     * @dev To create a swap / increase position order, collateral needs to first be transferred to the OrderVault,
     *  ExchangeRouter.openStrategy can then be called after. The transfer of tokens for collateral and
     *  the calling of ExchangeRouter.openStrategy should be done in a single transaction,
     *  otherwise the tokens may be transferred out by other users.
     */
    function openStrategy(CreateOrderParams calldata params) external payable returns (bytes32);

    function updateOrder(
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        uint256 minOutputAmount,
        bool autoCancel
    ) external payable;

    function cancelOrder(bytes32 key) external payable;
}
