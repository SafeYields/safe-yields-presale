// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStakingCallback } from "./ISafeYieldStakingCallback.sol";

interface ISafeYieldTokensDistributor is ISafeYieldStakingCallback {
    function approveRewardTokens(address[] calldata tokens) external;

    function pause() external;

    function unpause() external;

    function updateStaking(address newStaking) external;

    function claimRewards() external;

    function pendingRewards(address user) external view returns (uint256[] memory pendingTokenRewards);
}

interface ISafeYieldTokensDistributorV2 is ISafeYieldStakingCallback {
    event HandleActionBefore(address indexed user, bytes4 selector);
    event HandleActionAfter(address indexed user, bytes4 selector);
}
