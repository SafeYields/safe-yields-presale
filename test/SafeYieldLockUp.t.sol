// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { SafeYieldLockUp } from "src/SafeYieldLockUp.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";
import { VestingSchedule } from "src/types/SafeTypes.sol";
import { console } from "forge-std/Test.sol";

contract SafeYieldLockUpTest is SafeYieldBaseTest {
    function testVestForShouldFailIfAddressIsZero() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldLockUp.SYLU__INVALID_ADDRESS.selector);
        safeYieldLockUp.vestFor(address(0), 1_000e18);
    }

    function testVestForShouldFailIfAmountIsZero() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldLockUp.SYLU__INVALID_AMOUNT.selector);
        safeYieldLockUp.vestFor(ALICE, 0);
    }

    function testVestFor() public {
        vm.startPrank(protocolAdmin);

        safeYieldLockUp.vestFor(ALICE, 1_000e18);

        VestingSchedule memory aliceSchedule = safeYieldLockUp.getSchedules(ALICE);

        assertEq(aliceSchedule.start, 0);
        assertEq(aliceSchedule.totalAmount, 1_000e18);
        assertEq(aliceSchedule.amountClaimed, 0);
        assertEq(aliceSchedule.cliff, 0);
        assertEq(aliceSchedule.duration, safeYieldLockUp.VESTING_DURATION());
    }

    function testVestOverrideOldVest() public {
        vm.warp(1729166198000);
        vm.startPrank(protocolAdmin);

        console.log("Before IDO");

        safeYieldLockUp.vestFor(ALICE, 1_000e18);

        VestingSchedule memory aliceSchedule = safeYieldLockUp.getSchedules(ALICE);
        assertEq(aliceSchedule.totalAmount, 1_000e18);

        skip(5 days);

        safeYieldLockUp.vestFor(ALICE, 2_000e18);

        VestingSchedule memory aliceSchedule2 = safeYieldLockUp.getSchedules(ALICE);
        assertEq(aliceSchedule2.totalAmount, 3_000e18);

        skip(10 minutes);

        configs.setVestingStartTime(uint48(block.timestamp));

        console.log("After IDO");

        skip(10 minutes);
        safeYieldLockUp.vestFor(ALICE, 2_000e18);

        VestingSchedule memory aliceSchedule3 = safeYieldLockUp.getSchedules(ALICE);
        assertEq(aliceSchedule3.totalAmount, 2_000e18);

        skip(10 minutes);
        safeYieldLockUp.vestFor(ALICE, 2_000e18);

        VestingSchedule memory aliceSchedule4 = safeYieldLockUp.getSchedules(ALICE);
        assertEq(aliceSchedule4.totalAmount, 4_000e18);

        skip(10 * 30 * 24 * 60 * 60 seconds);

        safeYieldLockUp.vestFor(ALICE, 2_000e18);

        VestingSchedule memory aliceSchedule5 = safeYieldLockUp.getSchedules(ALICE);
        assertEq(aliceSchedule5.totalAmount, 2_000e18);
    }
}
