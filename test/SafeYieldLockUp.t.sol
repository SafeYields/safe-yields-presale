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

    //! tests flow -  unlocksSay and unstake from staking 
}
