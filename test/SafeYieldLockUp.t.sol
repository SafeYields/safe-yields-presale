// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { SafeYieldVesting } from "src/SafeYieldVesting.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";
import { VestingSchedule } from "src/types/SafeTypes.sol";
import { console } from "forge-std/Test.sol";

contract SafeYieldVestingTest is SafeYieldBaseTest {
    function testVestForShouldFailIfAddressIsZero() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldVesting.SYLU__INVALID_ADDRESS.selector);
        safeYieldVesting.vestFor(address(0), 1_000e18);
    }

    function testVestForShouldFailIfAmountIsZero() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldVesting.SYLU__INVALID_AMOUNT.selector);
        safeYieldVesting.vestFor(ALICE, 0);
    }

    function testVestFor() public {
        vm.startPrank(protocolAdmin);

        safeYieldVesting.vestFor(ALICE, 1_000e18);

        VestingSchedule memory aliceSchedule = safeYieldVesting.getSchedules(ALICE);

        assertEq(aliceSchedule.start, 0);
        assertEq(aliceSchedule.totalAmount, 1_000e18);
        assertEq(aliceSchedule.amountClaimed, 0);
        assertEq(aliceSchedule.cliff, 0);
        assertEq(aliceSchedule.duration, safeYieldVesting.VESTING_DURATION());
    }
}
