// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";
import { SafeToken } from "src/SafeToken.sol";
import { SafeYieldCoreContributorsVesting } from "src/SafeYieldCoreContributorsVesting.sol";
import { VestingSchedule } from "src/types/SafeTypes.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SafeYieldCoreContributorVestingTest is SafeYieldBaseTest {
    using Math for uint256;

    function testSayTokenContractSetCorrectly() public view {
        assertEq(address(contributorVesting.sayToken()), address(safeToken));
    }

    function testShouldFailIfMintingAllocationAgain() public {
        vm.prank(protocolAdmin);
        vm.expectRevert(SafeToken.SY__MAX_SUPPLY_EXCEEDED.selector);

        contributorVesting.mintSayAllocation(1_000e18);
    }

    function testAddCoreMember() public {
        vm.prank(protocolAdmin);

        contributorVesting.addMember(ALICE, 10_000e18);

        VestingSchedule memory aliceSchedule = contributorVesting.getSchedules(ALICE);

        assertEq(aliceSchedule.totalAmount, 10_000e18);
        assertEq(aliceSchedule.start, block.timestamp);
        assertEq(aliceSchedule.duration, contributorVesting.CORE_CONTRIBUTORS_VESTING_DURATION());
    }

    function testNewVestingScheduleForExistingCoreMemberAfterDuration() public {
        vm.prank(protocolAdmin);

        contributorVesting.addMember(ALICE, 10_000e18);

        VestingSchedule memory aliceSchedule = contributorVesting.getSchedules(ALICE);

        assertEq(aliceSchedule.totalAmount, 10_000e18);
        assertEq(aliceSchedule.start, block.timestamp);
        assertEq(aliceSchedule.duration, contributorVesting.CORE_CONTRIBUTORS_VESTING_DURATION());

        skip(365 * 24 * 60 * 60 seconds); // 1 year

        contributorVesting.unlockedAmount(ALICE);

        vm.prank(protocolAdmin);

        contributorVesting.addMember(ALICE, 12_000e18);

        VestingSchedule memory aliceSchedule2 = contributorVesting.getSchedules(ALICE);

        /**
         * When alice gets a new Schedule , she should receive all her SAY after one year
         */
        uint256 aliceTotalSayBalance = safeToken.balanceOf(ALICE);

        assertEq(aliceTotalSayBalance, 10_000e18);

        assertEq(aliceSchedule2.totalAmount, 12_000e18);
        assertEq(aliceSchedule2.start, block.timestamp);
        assertEq(aliceSchedule2.amountClaimed, 0);
        assertEq(aliceSchedule2.duration, contributorVesting.CORE_CONTRIBUTORS_VESTING_DURATION());
    }

    function testAddMultipleCoreMembersShouldRevertIfArrayMismatch() public {
        address[] memory members = new address[](2);

        members[0] = ALICE;
        members[1] = CHARLIE;

        uint128[] memory totalAmounts = new uint128[](1);
        totalAmounts[0] = 30_000e18;

        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldCoreContributorsVesting.SY_CCLU__LENGTH_MISMATCH.selector);
        contributorVesting.addMultipleMembers(members, totalAmounts);
    }

    function testAddMultipleCoreMembers() public {
        address[] memory members = new address[](2);
        members[0] = ALICE;
        members[1] = CHARLIE;

        uint128[] memory totalAmounts = new uint128[](2);
        totalAmounts[0] = 30_000e18;
        totalAmounts[1] = 10_000e18;

        skip(10 minutes);

        vm.startPrank(protocolAdmin);
        contributorVesting.addMultipleMembers(members, totalAmounts);

        VestingSchedule memory aliceSchedule = contributorVesting.getSchedules(ALICE);
        VestingSchedule memory charlieSchedule = contributorVesting.getSchedules(CHARLIE);

        assertEq(aliceSchedule.totalAmount, 30_000e18);
        assertEq(aliceSchedule.start, block.timestamp);
        assertEq(aliceSchedule.duration, contributorVesting.CORE_CONTRIBUTORS_VESTING_DURATION());

        assertEq(charlieSchedule.totalAmount, 10_000e18);
        assertEq(charlieSchedule.start, block.timestamp);
        assertEq(charlieSchedule.duration, contributorVesting.CORE_CONTRIBUTORS_VESTING_DURATION());
    }

    function testUnlockCoreMembersSayTokens() public {
        uint256 timeStart = block.timestamp;

        addCoreMember(BOB, 10_000e18);

        skip(10 days);

        uint256 bobSayBalancePrior = safeToken.balanceOf(BOB);

        vm.startPrank(BOB);
        contributorVesting.claimSayTokens();

        uint256 bobSayBalanceAfter = safeToken.balanceOf(BOB);

        VestingSchedule memory bobSchedule = contributorVesting.getSchedules(BOB);

        uint256 timePassed = block.timestamp - timeStart;

        uint256 expectedSayAmount = uint256(bobSchedule.totalAmount).mulDiv(timePassed, bobSchedule.duration);

        assertEq(bobSayBalanceAfter, bobSayBalancePrior + expectedSayAmount);
    }

    function testCreateSchedulesForMembersMultipleOps() public {
        skip(5 minutes);

        uint256 timeStarted = block.timestamp;

        vm.startPrank(protocolAdmin);
        contributorVesting.addMember(ALICE, 10_000e18);
        contributorVesting.addMember(BOB, 10_000e18);
        vm.stopPrank();

        uint256 aliceSayBalancePrior = safeToken.balanceOf(ALICE);
        uint256 bobSayBalancePrior = safeToken.balanceOf(BOB);

        assertEq(aliceSayBalancePrior, 0, "Alice Balance should be 0");
        assertEq(bobSayBalancePrior, 0, "Bob Balance should be 0");

        skip(1 days);

        vm.startPrank(ALICE);
        contributorVesting.claimSayTokens();

        uint256 aliceSayBalanceAfterFirstUnlock = safeToken.balanceOf(ALICE);

        VestingSchedule memory aliceSchedule = contributorVesting.getSchedules(ALICE);

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
        contributorVesting.claimSayTokens();
        vm.stopPrank();

        uint256 bobSayBalanceAfterFirstUnlock = safeToken.balanceOf(BOB);

        VestingSchedule memory bobSchedule = contributorVesting.getSchedules(BOB);

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
        contributorVesting.claimSayTokens();
        vm.stopPrank();

        uint256 aliceSayBalanceAfterLastUnlock = safeToken.balanceOf(ALICE);

        // uint256 aliceLastUnlockTimePassed = block.timestamp - timeStarted;

        uint256 expectedAmountAfter1year = aliceSchedule.totalAmount - aliceFirstUnlockExpectedSayAmount;

        assertEq(aliceSayBalanceAfterLastUnlock, aliceSayBalanceAfterFirstUnlock + expectedAmountAfter1year);

        //bob unlocks 1 year later
        vm.startPrank(BOB);
        contributorVesting.claimSayTokens();
        vm.stopPrank();

        uint256 bobSayBalanceAfterLastUnlock = safeToken.balanceOf(BOB);

        //uint256 bobLastUnlockTimePassed = block.timestamp - timeStarted;

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
        sayAllocation = bound(sayAllocation, 50_000e18, contributorVesting.CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT());
        numberOfMembers = bound(numberOfMembers, 2, 20);
        time = bound(time, block.timestamp, contributorVesting.CORE_CONTRIBUTORS_VESTING_DURATION());

        (address[] memory members, uint128[] memory totalAllocations) =
            getMembersAndAllocations(uint128(sayAllocation), numberOfMembers);

        skip(10 minutes);

        uint256 timeStarted = block.timestamp;

        vm.startPrank(protocolAdmin);
        contributorVesting.addMultipleMembers(members, totalAllocations);

        skip(time);

        //assertions
        for (uint256 i; i < members.length; i++) {
            if (contributorVesting.unlockedAmount(address(uint160(i + 50))) != 0) {
                vm.startPrank(address(uint160(i + 50)));
                contributorVesting.claimSayTokens();
                vm.stopPrank();
            } else {
                continue;
            }
        }

        uint256 timePassed = block.timestamp - timeStarted;

        for (uint256 i; i < members.length; i++) {
            VestingSchedule memory userSchedule = contributorVesting.getSchedules(address(uint160(i + 50)));
            if (userSchedule.totalAmount != 0) {
                uint256 expectedSayAmount = block.timestamp >= block.timestamp + userSchedule.duration
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
        contributorVesting.addMember(user, totalAmount);
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
