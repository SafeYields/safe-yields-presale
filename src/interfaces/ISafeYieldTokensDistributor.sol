// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStakingCallback } from "./ISafeYieldStakingCallback.sol";
import { Rewards } from "../types/SafeTypes.sol";

interface ISafeYieldTokensDistributor is ISafeYieldStakingCallback {
    event HandleActionBefore(address indexed user, bytes4 selector);
    event HandleActionAfter(address indexed user, bytes4 selector);

    function retrieve(address token, uint256 amount) external;

    function getUserRewardDebt(address user, address rewardAsset) external view returns (int256);

    function getAllRewardTokens() external view returns (address[] memory);

    function allPendingRewards(address user) external view returns (Rewards[] memory);

    function depositReward(address[] calldata rewardAssets, uint128[] calldata amounts) external;

    function claimAllRewards() external;

    function claimRewards(address rewardAsset) external;

    function handleActionBefore(address _user, bytes4 _selector) external;

    function handleActionAfter(address _user, bytes4 _selector) external;
}
