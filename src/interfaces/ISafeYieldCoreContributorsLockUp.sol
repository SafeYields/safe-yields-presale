// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISafeYieldCoreContributorsLockUp {
    function addMember(address _member, uint128 totalAmount) external;

    function addMultipleMembers(address[] calldata members, uint128[] calldata totalAmounts) external;

    function unlockedAmount(address member) external view returns (uint256 unlocked);

    function mintSayAllocation(uint256 totalSayAllocated) external;

    function vestedAmount(address member) external view returns (uint256 vestedAmount);

    function claimSayTokens() external;

    function pause() external;

    function unpause() external;
}
