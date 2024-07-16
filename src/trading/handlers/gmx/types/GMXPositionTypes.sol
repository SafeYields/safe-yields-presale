// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

struct PositionProps {
    Addresses addresses;
    Numbers numbers;
    Flags flags;
}

struct Numbers {
    uint256 sizeInUsd;
    uint256 sizeInTokens;
    uint256 collateralAmount;
    uint256 borrowingFactor;
    uint256 fundingFeeAmountPerSize;
    uint256 longTokenClaimableFundingAmountPerSize;
    uint256 shortTokenClaimableFundingAmountPerSize;
    uint256 increasedAtBlock;
    uint256 decreasedAtBlock;
    uint256 increasedAtTime;
    uint256 decreasedAtTime;
}

struct Flags {
    bool isLong;
}

struct Addresses {
    address account;
    address market;
    address collateralToken;
}
