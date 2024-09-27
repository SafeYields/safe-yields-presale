// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { VestingSchedule, PreSaleState } from "../types/SafeTypes.sol";

interface ISafeYieldLockUp {
    function vestFor(address user, uint256 amount) external;

    function approveVestingAgent(address agent, bool isApproved) external;

    function updateSayToken(address newSayToken) external;

    function updateStaking(address newStaking) external;

    function updatePreSale(address newPresale) external;

    function unlockSayTokens() external;

    function unlockedSayAmount(address member) external view returns (uint256 unlocked);

    function vestedAmount(address member) external view returns (uint256);

    function getSchedules(address user) external view returns (VestingSchedule memory schedule);

    function pause() external;

    function unpause() external;
}
