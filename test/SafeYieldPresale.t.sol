// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import {console} from "forge-std/Test.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {PreSaleState} from "src/types/SafeTypes.sol";
import {SafeYieldBaseTest} from "./SafeYieldBaseTest.t.sol";

contract SafeYieldPresaleTest is SafeYieldBaseTest {
    modifier startPresale() {
        vm.startPrank(protocolAdmin);
        presale.startPresale();
        vm.stopPrank();
        _;
    }

    function testMinAllocationIsLessThanMaxAllocation() public {
        uint256 minAllocation = presale.minAllocationPerWallet();
        uint256 maxAllocation = presale.maxAllocationPerWallet();

        assertLt(minAllocation, maxAllocation);
    }

    function testSafeStakingIsSetCorrectly() public {
        address stakingAddress = address(presale.safeYieldStaking());

        assertEq(stakingAddress, address(staking));
    }

    function testTokenPriceIsSetCorrectly() public {
        uint256 tokenPrice = presale.tokenPrice();

        assertEq(tokenPrice, 1e18);
    }

    function testSafeTokenIsSetCorrectly() public {
        address safeTokenAddress = address(presale.safeToken());

        assertEq(safeTokenAddress, address(safeToken));
    }

    function testReferrerCommissionIsSetCorrectly() public {
        uint256 referrerCommissionUsdc = presale.referrerCommissionUsdc();
        uint256 referrerCommissionSafe = presale.referrerCommissionSafeToken();

        assertEq(referrerCommissionUsdc, 5_00);
        assertEq(referrerCommissionSafe, 5_00);
    }

    function testPresaleNotStarted() public {
        assertEq(uint8(presale.preSaleState()), uint8(PreSaleState.NotStarted));
    }

    // function testBuyShouldFailIfPresaleNotStarted() public {
    //     vm.startPrank(ALICE);
    //     usdc.approve(address(presale), 1_000e6);

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             SafeYieldPresaleS.SAFE_YIELD_PRESALE_NOT_LIVE.selector
    //         )
    //     );
    //     presale.buy(ALICE, 1_000e6);
    // }

    // function testBuyTokensShouldFailIfPotentialSafeTokensExceedMaxTokenAllocation()
    //     public
    //     startPresale
    // {
    //     vm.startPrank(ALICE);
    //     usdc.approve(address(presale), 100_001e6);

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             SafeYieldPresaleS.SAFE_YIELD_INVALID_ALLOCATION.selector
    //         )
    //     );
    //     presale.buy(ALICE, 100_001e6);
    // }

    function testBuySafeTokensWithNoReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(ALICE, 1_000e6, bytes32(0));
    }

    function testBuySafeTokensWithReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(ALICE, 1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        console.logBytes32(refId);

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(BOB, 1_000e6, refId);

        skip(1 minutes);

        //alice redeem usdc
        vm.startPrank(ALICE);
        presale.redeemUsdcCommission();
        vm.stopPrank();
    }
}
