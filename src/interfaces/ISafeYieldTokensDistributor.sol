// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISafeYieldTokensDistributor {
    function approveRewardTokens(address[] calldata tokens) external;

    function pause() external;

    function unpause() external;

    function updateStaking(address newStaking) external;

    function claimRewards() external;

    function pendingRewards(address user) external view returns (uint256[] memory pendingTokenRewards);
}
