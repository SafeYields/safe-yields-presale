// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStakingCallback } from "./ISafeYieldStakingCallback.sol";

interface ISafeYieldTokensDistributor is ISafeYieldStakingCallback {
    event HandleActionBefore(address indexed user, bytes4 selector);
    event HandleActionAfter(address indexed user, bytes4 selector);

    // function approveRewardTokens(address[] calldata tokens) external;

    // function pause() external;

    // function unpause() external;

    // function updateStaking(address newStaking) external;

    // function claimRewards() external;

    // function pendingRewards(address user) external view returns (uint256[] memory pendingTokenRewards);

    function depositReward(address[] calldata rewardAssets, uint128[] calldata amounts) external;

    function handleActionBefore(address _user, bytes4 _selector) external;

    function handleActionAfter(address _user, bytes4 _selector) external;
}
