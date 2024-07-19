// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { CreateDepositParams, CreateWithdrawalParams, SetPricesParams, CreateOrderParams } from "../types/GMXTypes.sol";

interface IExchangeRouter {
    function sendWnt(address receiver, uint256 amount) external payable;

    // @dev Sends the given amount of tokens to the given address
    function sendTokens(address token, address receiver, uint256 amount) external payable;

    /**
     * @dev Receives and executes a batch of function calls on this contract.
     */
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
    /**
     * @dev To create a swap / increase position order, collateral needs to first be transferred to the OrderVault,
     *  ExchangeRouter.createOrder can then be called after. The transfer of tokens for collateral and
     *  the calling of ExchangeRouter.openStrategy should be done in a single transaction,
     *  otherwise the tokens may be transferred out by other users.
     */
    function createOrder(CreateOrderParams calldata params) external payable returns (bytes32);

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
