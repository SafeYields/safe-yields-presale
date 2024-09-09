// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISafeYieldLockUp {
    function vestFor(address user, uint256 amount) external;

    function unlockSayTokensFor(address user) external returns (uint256 sayTokensAvailable);

    function unlockedSayAmount(address member) external view returns (uint256 unlocked);

    function vestedAmount(address member) external view returns (uint256);

    function pause() external;

    function unpause() external;
}
