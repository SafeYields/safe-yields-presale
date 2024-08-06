// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { CoreContributorsLockUp } from "src/CoreContributorsLockUp.sol";
import { VestingSchedule } from "src/types/SafeTypes.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract CoreContributorLockUpTest is SafeYieldBaseTest {
    using Math for uint256;

    function testSayTokenContractSetCorrectly() public view {
        assertEq(address(contributorLockUp.sayToken()), address(safeToken));
    }

    function testAddCoreMember() public {
        vm.prank(protocolAdmin);

        contributorLockUp.addMember(ALICE, 10_000e18);
    }

    function testAddMultipleCoreMembersShouldRevertIfArrayMismatch() public {
        address[] memory members = new address[](2);

        members[0] = ALICE;
        members[1] = CHARLIE;

        uint128[] memory totalAmounts = new uint128[](1);
        totalAmounts[0] = 30_000e18;

        vm.startPrank(protocolAdmin);
        vm.expectRevert(CoreContributorsLockUp.SY_CCLU__LENGTH_MISMATCH.selector);
        contributorLockUp.addMultipleMembers(members, totalAmounts);
    }

    function testAddMultipleCoreMembers() public {
        address[] memory members = new address[](2);
        members[0] = ALICE;
        members[1] = CHARLIE;

        uint128[] memory totalAmounts = new uint128[](2);
        totalAmounts[0] = 30_000e18;
        totalAmounts[1] = 10_000e18;

        vm.startPrank(protocolAdmin);
        contributorLockUp.addMultipleMembers(members, totalAmounts);
    }

    function testUnlockCoreMembersSayTokens() public {
        uint256 timeStart = block.timestamp;

        addCoreMember(BOB, 10_000e18);

        skip(10 days);

        uint256 bobSayBalancePrior = safeToken.balanceOf(BOB);

        vm.startPrank(BOB);
        contributorLockUp.claimSayTokens();

        uint256 bobSayBalanceAfter = safeToken.balanceOf(BOB);

        VestingSchedule memory bobSchedule = contributorLockUp.getSchedules(BOB);

        uint256 timePassed = block.timestamp - timeStart;

        uint256 expectedSayAmount = uint256(bobSchedule.totalAmount).mulDiv(timePassed, bobSchedule.duration);

        assertEq(bobSayBalanceAfter, bobSayBalancePrior + expectedSayAmount);
    }

    function testCreateSchedulesForMembersMultipleOps() public {
        skip(5 minutes);

        uint256 timeStarted = block.timestamp;

        vm.startPrank(protocolAdmin);
        contributorLockUp.addMember(ALICE, 10_000e18);
        contributorLockUp.addMember(BOB, 10_000e18);
        vm.stopPrank();

        uint256 aliceSayBalancePrior = safeToken.balanceOf(ALICE);
        uint256 bobSayBalancePrior = safeToken.balanceOf(BOB);

        assertEq(aliceSayBalancePrior, 0, "Alice Balance should be 0");
        assertEq(bobSayBalancePrior, 0, "Bob Balance should be 0");

        skip(1 days);
        vm.startPrank(ALICE);
        contributorLockUp.claimSayTokens();

        uint256 aliceSayBalanceAfterFirstUnlock = safeToken.balanceOf(ALICE);

        VestingSchedule memory aliceSchedule = contributorLockUp.getSchedules(ALICE);

        uint256 aliceFirstUnlockTimePassed = block.timestamp - timeStarted;

        uint256 aliceFirstUnlockExpectedSayAmount =
            uint256(aliceSchedule.totalAmount).mulDiv(aliceFirstUnlockTimePassed, aliceSchedule.duration);

        vm.stopPrank();

        assertEq(
            aliceSayBalanceAfterFirstUnlock,
            aliceSayBalancePrior + aliceFirstUnlockExpectedSayAmount,
            "Alice First Unlock should be equal to expected amount"
        );

        skip(5 days);
        vm.startPrank(BOB);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        uint256 bobSayBalanceAfterFirstUnlock = safeToken.balanceOf(BOB);

        VestingSchedule memory bobSchedule = contributorLockUp.getSchedules(BOB);

        uint256 bobFirstUnlockTimePassed = block.timestamp - timeStarted;

        uint256 bobFirstUnlockExpectedSayAmount =
            uint256(bobSchedule.totalAmount).mulDiv(bobFirstUnlockTimePassed, bobSchedule.duration);

        vm.stopPrank();

        assertEq(
            bobSayBalanceAfterFirstUnlock,
            bobSayBalancePrior + bobFirstUnlockExpectedSayAmount,
            "Bob First Unlock should be equal to expected amount"
        );

        skip(365 * 24 * 60 * 60 seconds);

        //alice unlocks 1 year later
        vm.startPrank(ALICE);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        uint256 aliceSayBalanceAfterLastUnlock = safeToken.balanceOf(ALICE);

        uint256 aliceLastUnlockTimePassed = block.timestamp - timeStarted;

        uint256 expectedAmountAfter1year = aliceSchedule.totalAmount - aliceFirstUnlockExpectedSayAmount;

        assertEq(aliceSayBalanceAfterLastUnlock, aliceSayBalanceAfterFirstUnlock + expectedAmountAfter1year);

        //bob unlocks 1 year later
        vm.startPrank(BOB);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        uint256 bobSayBalanceAfterLastUnlock = safeToken.balanceOf(BOB);

        uint256 bobLastUnlockTimePassed = block.timestamp - timeStarted;

        uint256 bobExpectedAmountAfter1year = bobSchedule.totalAmount - bobFirstUnlockExpectedSayAmount;

        assertEq(bobSayBalanceAfterLastUnlock, bobSayBalanceAfterFirstUnlock + bobExpectedAmountAfter1year);

        assertEq(safeToken.balanceOf(BOB), 10_000e18);
        assertEq(safeToken.balanceOf(ALICE), 10_000e18);
    }

    function testFuzz__CreateSchedulesForCoreMembersMultipleOps(
        uint256 sayAllocation,
        uint256 numberOfMembers,
        uint256 time
    ) public {
        sayAllocation = bound(sayAllocation, 50_000e18, contributorLockUp.CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT());
        numberOfMembers = bound(numberOfMembers, 2, 20);
        time = bound(time, block.timestamp, block.timestamp + contributorLockUp.CORE_CONTRIBUTORS_VESTING_DURATION());

        (address[] memory members, uint128[] memory totalAllocations) =
            getMembersAndAllocations(uint128(sayAllocation), numberOfMembers);

        skip(10 minutes);

        uint256 timeStarted = block.timestamp;

        vm.startPrank(protocolAdmin);
        contributorLockUp.addMultipleMembers(members, totalAllocations);

        skip(time);

        //assertions
        for (uint256 i; i < members.length; i++) {
            if (contributorLockUp.unlockedAmount(address(uint160(i + 50))) != 0) {
                vm.startPrank(address(uint160(i + 50)));
                contributorLockUp.claimSayTokens();
                vm.stopPrank();
            } else {
                continue;
            }
        }

        uint256 timePassed = block.timestamp - timeStarted;

        for (uint256 i; i < members.length; i++) {
            VestingSchedule memory userSchedule = contributorLockUp.getSchedules(address(uint160(i + 50)));
            if (userSchedule.totalAmount != 0) {
                uint256 expectedSayAmount = block.timestamp >= userSchedule.duration
                    ? userSchedule.totalAmount
                    : uint256(userSchedule.totalAmount).mulDiv(timePassed, userSchedule.duration);

                uint256 userBalance = safeToken.balanceOf(address(uint160(i + 50)));

                assertEq(userBalance, expectedSayAmount, "User Balance should be equal to say balance");
            } else {
                continue;
            }
        }
    }

    function addCoreMember(address user, uint128 totalAmount) internal {
        vm.prank(protocolAdmin);
        contributorLockUp.addMember(user, totalAmount);
    }

    function getMembersAndAllocations(uint128 sayAllocation, uint256 numberOfMembers)
        internal
        pure
        returns (address[] memory members, uint128[] memory totalAllocations)
    {
        members = new address[](numberOfMembers);
        totalAllocations = new uint128[](numberOfMembers);

        for (uint256 i; i < numberOfMembers; i++) {
            members[i] = address(uint160(i + 50));
            totalAllocations[i] = sayAllocation;
        }
    }
}
