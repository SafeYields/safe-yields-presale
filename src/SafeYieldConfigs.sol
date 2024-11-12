// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldVesting } from "./interfaces/ISafeYieldVesting.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldRewardDistributor } from "./interfaces/ISafeYieldRewardDistributor.sol";
import { ISafeYieldConfigs } from "./interfaces/ISafeYieldConfigs.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract SafeYieldConfigs is ISafeYieldConfigs, Ownable2Step {
    address public override safeYieldLP;
    uint48 public override vestStartTime;
    ISafeYieldPreSale public override safeYieldPresale;
    ISafeYieldRewardDistributor public override safeYieldDistributor;
    ISafeYieldVesting public override safeYieldVesting;
    ISafeYieldStaking public override safeYieldStaking;

    event SafeYieldLpSet(address indexed LPset, uint256 indexed vestStart);
    event PresaleSet(address indexed presale);
    event VestingSet(address indexed Vesting);
    event SafeStakingUpdated(address indexed newStaking);
    event RewardDistributorSet(address indexed distributor);

    error SYC__INVALID_ADDRESS();

    constructor(address protocolAdmin) Ownable(protocolAdmin) { }

    function setIDO(address lp) external override onlyOwner {
        if (lp == address(0)) revert SYC__INVALID_ADDRESS();

        safeYieldLP = lp;

        vestStartTime = uint48(block.timestamp);

        emit SafeYieldLpSet(lp, block.timestamp);
    }

    function setPresale(address _presale) external override onlyOwner {
        if (_presale == address(0)) revert SYC__INVALID_ADDRESS();

        safeYieldPresale = ISafeYieldPreSale(_presale);

        emit PresaleSet(_presale);
    }

    function setVesting(address _Vesting) external override onlyOwner {
        if (_Vesting == address(0)) revert SYC__INVALID_ADDRESS();

        safeYieldVesting = ISafeYieldVesting(_Vesting);

        emit VestingSet(_Vesting);
    }

    function updateSafeStaking(address _newStaking) external override onlyOwner {
        if (_newStaking == address(0)) revert SYC__INVALID_ADDRESS();

        safeYieldStaking = ISafeYieldStaking(_newStaking);

        emit SafeStakingUpdated(_newStaking);
    }

    /**
     * @notice Set the reward distributor contract.
     * @param _distributor The address of the reward distributor contract.
     */
    function setRewardDistributor(address _distributor) external override onlyOwner {
        if (_distributor == address(0)) revert SYC__INVALID_ADDRESS();

        safeYieldDistributor = ISafeYieldRewardDistributor(_distributor);

        emit RewardDistributorSet(_distributor);
    }
}
