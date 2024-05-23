// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { PreSaleState } from "src/types/SafeTypes.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";

contract SafeYieldStakingTest is SafeYieldBaseTest {
    /*//////////////////////////////////////////////////////////////
                              NORMAL TESTS
    //////////////////////////////////////////////////////////////*/
    modifier mintSafeTokens(uint256 amount) {
        vm.prank(address(distributor));
        safeToken.mint(amount);
        _;
    }

    function testIfSafeTokensAreSetCorrectly() public view {
        assertEq(address(safeToken), address(staking.safeToken()));
    }

    function testIfSSafeTokensAreSetCorrectly() public view {
        assertEq(address(sToken), address(staking.sSafeToken()));
    }

    function testIfUsdcTokensAreSetCorrectly() public view {
        assertEq(address(usdc), address(staking.usdc()));
    }

    function testStakeShouldRevertIfPreSaleIsLiveAndCallerIsNotAdmin() public {
        vm.prank(protocolAdmin);
        presale.startPresale();

        vm.expectRevert(abi.encodeWithSelector(SafeYieldStaking.SAFE_YIELD_STAKING_LOCKED.selector));

        vm.prank(NOT_ADMIN);
        staking.stake(NOT_ADMIN, 1_000e18);
    }

    function testStakeSafeTokens() public mintSafeTokens(10_000e18) {
        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);

        staking.stake(ALICE, 1_000e18);

        assertEq(staking.totalStaked(), 1_000e18);
        assertEq(staking.getUserStake(ALICE).stakedSafeTokenAmount, 1_000e18);
    }
}
