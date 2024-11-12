// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./ISafeYieldStaking.sol";
import { ISafeYieldVesting } from "./ISafeYieldVesting.sol";
import { ISafeYieldPreSale } from "./ISafeYieldPreSale.sol";
import { ISafeYieldStaking } from "./ISafeYieldStaking.sol";
import { ISafeYieldRewardDistributor } from "./ISafeYieldRewardDistributor.sol";

interface ISafeYieldConfigs {
    function safeYieldLP() external view returns (address);

    function safeYieldPresale() external view returns (ISafeYieldPreSale);

    function vestStartTime() external view returns (uint48 vestStartTime);

    function safeYieldDistributor() external view returns (ISafeYieldRewardDistributor);

    function safeYieldVesting() external view returns (ISafeYieldVesting);

    function safeYieldStaking() external view returns (ISafeYieldStaking);

    function setIDO(address lp) external;

    function setPresale(address _presale) external;

    function setVesting(address _Vesting) external;

    function updateSafeStaking(address _newStaking) external;

    function setRewardDistributor(address _distributor) external;
}
