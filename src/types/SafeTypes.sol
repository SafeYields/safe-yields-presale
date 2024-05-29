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
    uint128 stakeAmount;
    int128 usdcRewardsDebt;
    int128 safeRewardsDebt;
}

struct ReferrerRecipient {
    address referrerRecipient;
    uint128 usdcAmountInvested;
}
