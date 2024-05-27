// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { sSafeToken } from "src/sSafeToken.sol";
import { console } from "forge-std/Test.sol";

contract sSafeTokenTest is SafeYieldBaseTest {
    function test_MintAndCheckBalance() public {
        vm.prank(address(staking));
        sToken.mint(address(this), 1000e18);

        assertEq(sToken.balanceOf(address(this)), 1000e18);
    }

    function test_BurnAndCheckBalance() public {
        vm.prank(address(staking));
        sToken.mint(address(this), 1000e18);

        vm.prank(address(staking));
        sToken.burn(address(this), 500e18);

        assertEq(sToken.balanceOf(address(this)), 500e18);
    }

    function testTransferToAnotherShouldFail() public {
        vm.prank(address(staking));
        sToken.mint(address(staking), 1000e18);

        vm.prank(address(staking));
        vm.expectRevert(sSafeToken.SAFE_YIELD__TRANSFER_NOT_ALLOWED.selector);
        sToken.transfer(address(BOB), 500e18);
    }
}
