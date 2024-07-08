// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

enum OrderType {
    LIMIT,
    MARKET
}

struct Strategy {
    uint256 amount;
    uint256 limitPrice;
    uint256 stopLossPrice;
    uint256 takeProfitPrice;
    uint256 leverage;
    int256 pnl;
    OrderType orderType;
    address token;
    address strategyHandler;
    bool isLong;
    bool isMatured;
}
