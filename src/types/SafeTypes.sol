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

struct UserDepositStats {
    uint48 lastDepositTimestamp;
    uint128 amountUnutilized;
    uint128 amountUtilized;
}

struct StrategyStats {
    uint48 timestampOfStrategy;
    uint256 amountRequested;
    uint256 lastAmountAvailable;
    int256 pnl;
}

struct VestingSchedule {
    uint128 totalAmount;
    uint128 amountClaimed;
    uint48 start;
    uint48 cliff;
    uint48 duration;
}

struct RewardToken {
    uint256 accRewardPerShare;
    bool isRewardToken;
}
