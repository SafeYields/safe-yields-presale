// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { CoreContributorsLockUp } from "src/CoreContributorsLockUp.sol";
import { VestingSchedule } from "src/types/SafeTypes.sol";

contract CoreContributorLockUpTest is SafeYieldBaseTest {
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
        addCoreMember(BOB, 10_000e18);

        skip(10 days);

        uint256 bobSayBalancePrior = safeToken.balanceOf(BOB);

        vm.startPrank(BOB);
        contributorLockUp.claimSayTokens();

        uint256 bobSayBalanceAfter = safeToken.balanceOf(BOB);

        assertGt(bobSayBalanceAfter, bobSayBalancePrior);
    }

    function testCreateSchedulesForMembersMultipleOps() public {
        skip(5 minutes);
        vm.startPrank(protocolAdmin);
        contributorLockUp.addMember(ALICE, 10_000e18);
        contributorLockUp.addMember(BOB, 10_000e18);
        vm.stopPrank();

        assertEq(safeToken.balanceOf(ALICE), 0, "Alice Balance should be 0");
        assertEq(safeToken.balanceOf(BOB), 0, "Bob Balance should be 0");

        skip(1 days);
        vm.startPrank(ALICE);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        assertGt(safeToken.balanceOf(ALICE), 0, "Alice Balance should be greater than zero");

        skip(5 days);
        vm.startPrank(BOB);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        assertGt(safeToken.balanceOf(BOB), 0, "Bob Balance should be greater than zero");

        skip(365 * 24 * 60 * 60 seconds);
        //alice unlocks 1 year later
        vm.startPrank(ALICE);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        //bob unlocks 1 year later
        vm.startPrank(BOB);
        contributorLockUp.claimSayTokens();
        vm.stopPrank();

        assertEq(safeToken.balanceOf(BOB), 10_000e18);
        assertEq(safeToken.balanceOf(ALICE), 10_000e18);
    }

    function testFuzz__CreateSchedulesForCoreMembersMultipleOps(
        uint256 sayAllocation,
        uint256 numberOfMembers,
        uint256 timePassed
    ) public {
        sayAllocation = bound(sayAllocation, 50_000e18, contributorLockUp.CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT());
        numberOfMembers = bound(numberOfMembers, 2, 20);
        timePassed =
            bound(timePassed, block.timestamp, block.timestamp + contributorLockUp.CORE_CONTRIBUTORS_VESTING_DURATION());

        (address[] memory members, uint128[] memory totalAllocations) =
            getMembersAndAllocations(uint128(sayAllocation), numberOfMembers);

        vm.startPrank(protocolAdmin);
        contributorLockUp.addMultipleMembers(members, totalAllocations);

        skip(timePassed);

        for (uint256 i; i < members.length; i++) {
            if (contributorLockUp.unlockedAmount(address(uint160(i + 50))) != 0) {
                vm.startPrank(address(uint160(i + 50)));
                contributorLockUp.claimSayTokens();
                vm.stopPrank();
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
