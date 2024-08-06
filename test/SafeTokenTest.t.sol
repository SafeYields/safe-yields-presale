// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { SafeToken } from "src/SafeToken.sol";
import { console } from "forge-std/Test.sol";

contract SafeTokenTest is SafeYieldBaseTest {
    /**
     * 2,000,000e18 for team operations
     * 1,000,000e18 for Core contributors
     * 2,000,000e18 for future liquidity
     * 2,000,000e18 for early investors rounds
     */
    function testRemainingSupplyAfterMintingToMultiSigs() public view {
        uint256 teamOperationsSupply = 2_000_000e18;
        uint256 coreContributorsSupply = 1_000_000e18;
        uint256 futureLiquiditySupply = 2_000_000e18;
        uint256 earlyInvestorsSupply = 2_000_000e18;
        uint256 idoSupply = 2_000_000e18;
        uint256 stakingEmissionsSupply = 11_000_000e18;

        uint256 totalSupply = teamOperationsSupply + futureLiquiditySupply + earlyInvestorsSupply + idoSupply
            + stakingEmissionsSupply + coreContributorsSupply;
        uint256 tokensRemaining = safeToken.MAX_SUPPLY() - totalSupply;

        assertEq(tokensRemaining, 0);
        assertEq(safeToken.totalSupply(), totalSupply);
        assertEq(safeToken.balanceOf(safeToken.TEAM_OPERATIONS_IDO()), teamOperationsSupply + idoSupply);
        assertEq(safeToken.balanceOf(safeToken.FUTURE_LIQUIDITY()), futureLiquiditySupply);
    }

    function testSetAllocationLimitShouldFailIfNotADMIN_ROLE() public {
        vm.expectRevert(abi.encodeWithSelector(SafeToken.SY__ONLY_ADMIN_ROLE.selector));
        vm.prank(NOT_ADMIN);
        safeToken.setAllocationLimit(msg.sender, 1000e18);
    }

    function testSetAllocationLimitShouldFailIfAlreadySet() public {
        vm.expectRevert(abi.encodeWithSelector(SafeToken.SY__MAX_SUPPLY_EXCEEDED.selector));
        vm.prank(protocolAdmin);
        safeToken.setAllocationLimit(address(distributor), 11_000_000e18);
    }

    function testMintShouldFailIfNotMINTER_ROLE() public {
        vm.expectRevert(abi.encodeWithSelector(SafeToken.SY__ONLY_MINTER_ROLE.selector));
        vm.prank(NOT_MINTER);
        safeToken.mint(1_000e18);
    }

    // function testMintShouldFailIfMaxMintAllocExceeded() public {
    //     vm.expectRevert(abi.encodeWithSelector(SafeToken.SY__MAX_SUPPLY_EXCEEDED.selector));
    //     vm.prank(address(presale));
    //     safeToken.mint(1_000e18);
    // }
}
