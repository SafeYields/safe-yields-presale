// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./ISafeYieldLockUp.sol";
import { ISafeYieldPreSale } from "./ISafeYieldPreSale.sol";
import { ISafeYieldStaking } from "./ISafeYieldStaking.sol";
import { ISafeYieldRewardDistributor } from "./ISafeYieldRewardDistributor.sol";

interface ISafeYieldConfigs {
    function safeYieldLP() external view returns (address);

    function safeYieldPresale() external view returns (ISafeYieldPreSale);

    function vestStartTime() external view returns (uint48 vestStartTime);

    function safeYieldDistributor() external view returns (ISafeYieldRewardDistributor);

    function safeYieldLockUp() external view returns (ISafeYieldLockUp);

    function safeYieldStaking() external view returns (ISafeYieldStaking);

    function setVestingStartTime(uint48 _vestStartTime) external;

    function setLpAddress(address lp) external;

    function setPresale(address _presale) external;

    function setLockUp(address _lockUp) external;

    function updateSafeStaking(address _newStaking) external;

    function setRewardDistributor(address _distributor) external;
}
