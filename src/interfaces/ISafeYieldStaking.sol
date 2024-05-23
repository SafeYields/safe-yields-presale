// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Stake } from "../types/SafeTypes.sol";

interface ISafeYieldStaking {
    function totalStaked() external view returns (uint128);
    function rewardsEarned() external view returns (uint128 pendingUsdcReward, uint128 pendingSafeTokenReward);

    function rewardsPerToken() external view returns (uint128 usdcRewardsPerToken, uint128 safeTokenRewardsPerToken);

    function stake(uint128 amount, address user) external;

    function unstake(address user, uint128 amount) external;

    function stakeFor(address investor, uint128 investorAmount, address referrer, uint128 referrerAmount) external;
    function claimReward() external;

    function updateUsdcRewardPerShare(uint128 newRewardPerShare) external;

    function updateSafeTokenRewardPerShare(uint128 newRewardPerShare) external;

    function updateUsdcRewardRate(uint64 newRewardRate) external;

    function updateSafeTokenRewardRate(uint64 newRewardRate) external;

    function setPresale(address _presale) external;

    function getUserStake(address _user) external view returns (Stake memory stake);
}
