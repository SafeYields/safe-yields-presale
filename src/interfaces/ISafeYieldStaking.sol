// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Stake } from "../types/SafeTypes.sol";

interface ISafeYieldStaking {
    function updateRewards() external;

    function stakeFor(address user, uint128 amount) external;

    function autoStakeForBothReferrerAndRecipient(
        address recipient,
        uint128 recipientAmount,
        address referrer,
        uint128 referrerAmount
    ) external;

    function unStake(address user, uint128 amount) external;

    function claimRewards() external;

    function calculatePendingRewards(address user) external returns (uint128 pendingRewards);

    function setPresale(address _presale) external;

    function setRewardDistributor(address _distributor) external;

    function getUserStake(address _user) external view returns (Stake memory stake);
}
