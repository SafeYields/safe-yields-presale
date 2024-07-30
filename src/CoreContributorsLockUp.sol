// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ICoreContributorsLockUp } from "./interfaces/ICoreContributorsLockUp.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { VestingSchedule } from "./types/SafeTypes.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract CoreContributorsLockUp is ICoreContributorsLockUp, Ownable2Step, Pausable {
    using Math for uint256;
    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES AND CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint128 public constant CORE_CONTRIBUTORS_TOTAL_BRR_AMOUNT = 1_000_000e18;
    uint48 public constant CORE_CONTRIBUTORS_VESTING_DURATION = 365 * 24 * 60 * 60 seconds; // 1 year

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address user => VestingSchedule) public schedules;

    ISafeToken public sayToken;
    uint128 public totalSayTokensAllocated;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MemberAdded(address indexed member, uint128 indexed totalAmount);
    event SayTokensUnlocked(address indexed member, uint256 indexed releasableBRR);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SY_CCLU__INVALID_ADDRESS();
    error SY_CCLU_LENGTH_MISMATCH();
    error SY_CCLU__NO_SAY_TO_UNLOCK();
    error SY_CCLU__INVALID_AMOUNT();

    constructor(address protocolAdmin, address _sayToken) Ownable(protocolAdmin) {
        if (protocolAdmin == address(0) || _sayToken == address(0)) revert SY_CCLU__INVALID_ADDRESS();

        sayToken = ISafeToken(_sayToken);
    }

    function addMultipleMembers(address[] calldata members, uint128[] calldata totalAmounts) external onlyOwner {
        if (members.length != totalAmounts.length) revert SY_CCLU_LENGTH_MISMATCH();

        uint256 numOfMembers = members.length;
        for (uint256 i; i < numOfMembers; i++) {
            addMember(members[i], totalAmounts[i]);
        }
    }

    function claimSayTokens() external override {
        uint256 releasableBRR = unlockedAmount(msg.sender);

        VestingSchedule storage schedule = schedules[msg.sender];

        if (releasableBRR == 0) {
            revert SY_CCLU__NO_SAY_TO_UNLOCK();
        }

        schedule.amountClaimed += uint128(releasableBRR);

        emit SayTokensUnlocked(msg.sender, releasableBRR);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function addMember(address _member, uint128 totalAmount) public override onlyOwner {
        if (_member == address(0)) revert SY_CCLU__INVALID_ADDRESS();
        if (totalAmount > 1e6) revert SY_CCLU__INVALID_AMOUNT();

        if (totalSayTokensAllocated + totalAmount > CORE_CONTRIBUTORS_TOTAL_BRR_AMOUNT) {
            totalAmount = CORE_CONTRIBUTORS_TOTAL_BRR_AMOUNT - totalSayTokensAllocated;
        }

        if (schedules[_member].start == 0) {
            schedules[_member].start = uint48(block.timestamp);
            schedules[_member].duration = uint48(block.timestamp) + CORE_CONTRIBUTORS_VESTING_DURATION;
        }

        schedules[_member].totalAmount += totalAmount;

        totalSayTokensAllocated += totalAmount;

        emit MemberAdded(_member, totalAmount);
    }

    function unlockedAmount(address member) public view override returns (uint256 unlocked) {
        VestingSchedule memory schedule = schedules[member];

        if (schedule.totalAmount == 0 || block.timestamp < schedule.cliff) {
            return 0;
        }

        uint256 vested = vestedAmount(member);
        unlocked = vested - schedule.amountClaimed;
    }

    function vestedAmount(address member) public view override returns (uint256) {
        VestingSchedule memory schedule = schedules[member];

        if (block.timestamp < schedule.cliff) {
            return 0;
        } else if (block.timestamp >= schedule.duration) {
            return schedule.totalAmount;
        } else {
            uint256 durationPassed = block.timestamp - schedule.start;

            uint256 totalVested =
                uint256(schedule.totalAmount).mulDiv(durationPassed, schedule.duration, Math.Rounding.Floor);

            return totalVested;
        }
    }
}