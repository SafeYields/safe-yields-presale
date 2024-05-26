// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

struct ReferrerInfo {
    address referrer;
    uint128 usdcVolume;
    uint128 safeTokenVolume;
}

enum PreSaleState {
    NotStarted,
    Live,
    Ended
}

enum StakingEmissionState {
    NotStarted,
    Live, //STAKE
    Ended //USDC

}

struct ContractShare {
    int256 shareDebt;
    address contract_;
    uint16 share;
}

struct Stake {
    uint128 stakedSafeTokenAmount;
    uint128 safeRewards;
    uint128 usdcPerTokenRewardClaimed;
    uint128 usdcRewards;
    uint128 safePerTokenRewardClaimed;
    uint128 lastUpdateTimestamp;
}

struct ReferrerRecipient {
    address referrerRecipient;
    uint128 usdcAmountInvested;
}
