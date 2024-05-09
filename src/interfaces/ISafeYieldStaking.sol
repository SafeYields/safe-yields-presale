// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface ISafeYieldStaking {
    function stake(uint128 amount, address user) external;
    function unstake(uint128 amount) external;
    function claimRewards() external;
    function getStakedBalance(address user) external view returns (uint128);
    function getRewardsBalancse(
        address user
    ) external view returns (uint128, uint128);
}
