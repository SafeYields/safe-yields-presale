// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Stake } from "../types/SafeTypes.sol";

interface ISafeYieldStaking {
    function totalStaked() external view returns (uint128);

    function updateRewards() external;

    function stakeFor(address user, uint128 amount) external;

    function autoStakeForBothReferrerAndRecipient(
        address recipient,
        uint128 recipientAmount,
        address referrer,
        uint128 referrerAmount
    ) external;

    function unStake(uint128 amount) external;

    function unStakeFor(address user, uint128 amount) external;

    function claimRewards(address user) external;

    function calculatePendingRewards(address user)
        external
        returns (
            uint128 pendingUsdcRewards,
            uint128 pendingSafeRewards,
            int128 accumulateUsdcRewards,
            int128 accumulateSafeRewards
        );

    function setPresale(address _presale) external;

    function pause() external;

    function unpause() external;

    function setRewardDistributor(address _distributor) external;

    function getUserStake(address _user) external view returns (Stake memory stake);
}
