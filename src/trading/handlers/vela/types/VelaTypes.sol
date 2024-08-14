// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

enum OrderType {
    MARKET,
    LIMIT,
    STOP,
    STOP_LIMIT,
    TRAILING_STOP
}

struct Position {
    address owner;
    address refer;
    int256 realisedPnl;
    uint256 averagePrice;
    uint256 collateral;
    uint256 entryFundingRate;
    uint256 lastIncreasedTime;
    uint256 lastPrice;
    uint256 reserveAmount;
    uint256 size;
}

struct ConfirmInfo {
    bool confirmDelayStatus;
    uint256 pendingDelayCollateral;
    uint256 pendingDelaySize;
    uint256 delayStartTime;
}

enum OrderStatus {
    NONE,
    PENDING,
    FILLED,
    CANCELED
}

struct OrderInfo {
    OrderStatus status;
    uint256 lmtPrice;
    uint256 pendingSize;
    uint256 pendingCollateral;
    uint256 positionType;
    uint256 stepAmount;
    uint256 stepType;
    uint256 stpPrice;
}
