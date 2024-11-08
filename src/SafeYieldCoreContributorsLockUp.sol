// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ISafeYieldCoreContributorsLockUp } from "./interfaces/ISafeYieldCoreContributorsLockUp.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { VestingSchedule } from "./types/SafeTypes.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title SafeYieldCoreContributorsLockUp
 * @dev This contract manages the vesting for 12 months and allocation of 1 Million SAY tokens for core contributors,
 *   allowing claim and mint operations with pausable functionality.
 * @author @0xm00k
 */
contract SafeYieldCoreContributorsLockUp is ISafeYieldCoreContributorsLockUp, Ownable2Step, Pausable {
    using Math for uint256;
    using SafeERC20 for ISafeToken;
    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES AND CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint128 public constant CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT = 1_000_000e18;
    uint48 public constant CORE_CONTRIBUTORS_VESTING_DURATION = 365 * 24 * 60 * 60 seconds; // 1 year
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address user => VestingSchedule schedule) public schedules;
    ISafeToken public sayToken;
    uint128 public totalSayTokensAllocated;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MemberAdded(address indexed member, uint128 indexed totalAmount);
    event SayTokensUnlocked(address indexed member, uint256 indexed releasableSAY);
    event SayAllocationsMinted(uint256 indexed sayAllocation);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SY_CCLU__INVALID_ADDRESS();
    error SY_CCLU__LENGTH_MISMATCH();
    error SY_CCLU__NO_SAY_TO_UNLOCK();
    error SY_CCLU__INVALID_AMOUNT();
    error SY_CCLU__NO_MORE_SAY();

    constructor(address protocolAdmin, address _sayToken) Ownable(protocolAdmin) {
        if (protocolAdmin == address(0) || _sayToken == address(0)) revert SY_CCLU__INVALID_ADDRESS();

        sayToken = ISafeToken(_sayToken);
    }

    function addMultipleMembers(address[] calldata members, uint128[] calldata totalAmounts)
        external
        override
        onlyOwner
    {
        if (members.length != totalAmounts.length) revert SY_CCLU__LENGTH_MISMATCH();

        uint256 numOfMembers = members.length;
        for (uint256 i; i < numOfMembers; i++) {
            addMember(members[i], totalAmounts[i]);
        }
    }

    function claimSayTokens() external override whenNotPaused {
        uint256 releasableSAY = unlockedAmount(msg.sender);

        if (releasableSAY == 0) {
            revert SY_CCLU__NO_SAY_TO_UNLOCK();
        }

        schedules[msg.sender].amountClaimed += uint128(releasableSAY);

        sayToken.safeTransfer(msg.sender, releasableSAY);

        emit SayTokensUnlocked(msg.sender, releasableSAY);
    }

    function mintSayAllocation() external override onlyOwner {
        sayToken.mint(CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT);

        emit SayAllocationsMinted(CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function addMember(address _member, uint128 totalAmount) public override onlyOwner {
        if (_member == address(0)) revert SY_CCLU__INVALID_ADDRESS();
        if (totalAmount < 1e18) revert SY_CCLU__INVALID_AMOUNT();

        if (totalSayTokensAllocated + totalAmount > CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT) {
            totalAmount = CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT - totalSayTokensAllocated;
        }
        /**
         * @dev
         * We avoid reverting in this function to prevent DOS.
         * Instead, we simply return. For example, if there are 10 members to be added and 100,000e18
         * tokens to be distributed among them, but only 5 members can be successfully allocated shares,
         * the remaining members will not be added since there wouldn't be enough tokens left.
         * - Suppose each member requires a different share.
         * - If we have 6 members and 50,000e18 tokens:
         *   - Member 1 requires 10,000e18 tokens.
         *   - Member 2 requires 20,000e18 tokens.
         *   - Member 3 requires 5,000e18 tokens.
         *   - Member 4 requires 15,000e18 tokens.
         *   - Member 5 requires 30,000e18 tokens.
         *   - Member 6 requires 25,000e18 tokens.
         * - Members 1, 2, and 3 can be successfully allocated shares (10,000e18 + 20,000e18 + 5,000e18 = 35,000e18).
         * - Member 4 requires 15,000e18 tokens, but only 15,000e18 tokens are left.
         * - Members 5 and 6 will not be added since there aren't enough tokens left for their shares.
         */
        if (totalAmount == 0) return;

        if (schedules[_member].start == 0) {
            schedules[_member].start = uint48(block.timestamp);
            schedules[_member].duration = CORE_CONTRIBUTORS_VESTING_DURATION;
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
        } else if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            uint256 durationPassed = block.timestamp - schedule.start;

            uint256 totalVested =
                uint256(schedule.totalAmount).mulDiv(durationPassed, schedule.duration, Math.Rounding.Floor);

            return totalVested;
        }
    }

    function getSchedules(address user) external view returns (VestingSchedule memory schedule) {
        return schedules[user];
    }
}
