// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

enum OrderType {
    LIMIT,
    MARKET
}

struct Strategy {
    uint256 id;
    uint256 amountFunded;
    uint256 lastFMTotalDeposits;
    uint256 triggerPrice;
    uint256 leverage;
    int256 pnl;
    OrderType orderType;
    address token;
    address handler;
    uint48 lastFundedAt;
    bool isLong;
    bool isMatured;
}

struct UserDepositDetails {
    uint48 lastDepositedAt;
    uint128 amountUnutilized;
    uint128 amountUtilized;
}
