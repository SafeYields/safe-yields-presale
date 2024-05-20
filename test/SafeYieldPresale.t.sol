// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import {console} from "forge-std/Test.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {PreSaleState} from "src/types/SafeTypes.sol";
import {SafeYieldBaseTest} from "./SafeYieldBaseTest.t.sol";

contract SafeYieldPresaleTest is SafeYieldBaseTest {
    /*//////////////////////////////////////////////////////////////
                              NORMAL TESTS
    //////////////////////////////////////////////////////////////*/
    modifier startPresale() {
        vm.startPrank(protocolAdmin);
        presale.startPresale();
        vm.stopPrank();
        _;
    }

    modifier pause() {
        vm.startPrank(protocolAdmin);
        presale.pause();
        vm.stopPrank();
        _;
    }

    function testMinAllocationIsLessThanMaxAllocation() public view {
        uint256 minAllocation = presale.minAllocationPerWallet();
        uint256 maxAllocation = presale.maxAllocationPerWallet();

        assertLt(minAllocation, maxAllocation);
    }

    function testSafeStakingIsSetCorrectly() public view {
        address stakingAddress = address(presale.safeYieldStaking());

        assertEq(stakingAddress, address(staking));
    }

    function testTokenPriceIsSetCorrectly() public view {
        uint256 tokenPrice = presale.tokenPrice();

        assertEq(tokenPrice, 1e18);
    }

    function testSafeTokenIsSetCorrectly() public view {
        address safeTokenAddress = address(presale.safeToken());

        assertEq(safeTokenAddress, address(safeToken));
    }

    function testReferrerCommissionIsSetCorrectly() public view {
        uint256 referrerCommissionUsdc = presale.referrerCommissionUsdc();
        uint256 referrerCommissionSafe = presale.referrerCommissionSafeToken();

        assertEq(referrerCommissionUsdc, 5_00);
        assertEq(referrerCommissionSafe, 5_00);
    }

    function testPresaleNotStarted() public view {
        assertEq(uint8(presale.preSaleState()), uint8(PreSaleState.NotStarted));
    }

    function testCreateReferrerId() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(ALICE, 1_000e6, bytes32(0));

        bytes32 refId = presale.createReferrerId();

        assertEq(refId, keccak256(abi.encodePacked(ALICE)));
    }

    function testCreateReferrerIdShouldFailIfCallerHasNotInvested()
        public
        startPresale
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldPresale.SAFE_YIELD_ZERO_BALANCE.selector
            )
        );
        presale.createReferrerId();
        vm.stopPrank();
    }

    function testBuyShouldFailIfPresaleNotStarted() public {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldPresale.SAFE_YIELD_PRESALE_NOT_LIVE.selector
            )
        );
        presale.deposit(ALICE, 1_000e6, bytes32(0));
    }

    function testBuySafeTokensShouldFailPotentialSafeTokensLessThanMinTokenAllocation()
        public
        startPresale
    {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 999e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldPresale
                    .SAFE_YIELD_MIN_WALLET_ALLOCATION_EXCEEDED
                    .selector
            )
        );

        presale.deposit(ALICE, 999e6, bytes32(0));
    }

    function testBuyTokensShouldFailIfReferrerIdIsInvalid()
        public
        startPresale
    {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldPresale.SAFE_YIELD_UNKNOWN_REFERRER.selector
            )
        );

        presale.deposit(
            ALICE,
            1_000e6,
            keccak256(abi.encode("invalid_referrer_id"))
        );
    }

    function testBuyTokesShouldFailIfReferrerIsSameAsBuyer()
        public
        startPresale
    {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(ALICE, 1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldPresale.SAFE_YIELD_REFERRAL_TO_SELF.selector
            )
        );

        presale.deposit(ALICE, 1_000e6, refId);
    }

    function testBuyTokensShouldFailIfPotentialSafeTokensExceedMaxTokenAllocation()
        public
        startPresale
    {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 100_001e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldPresale
                    .SAFE_YIELD_MAX_WALLET_ALLOCATION_EXCEEDED
                    .selector
            )
        );

        presale.deposit(ALICE, 100_001e6, bytes32(0));
    }

    // function testBuyTokensShouldFailIfReferrersInvestmentPlusCommissionsExceedMaxTokenAllocation()
    //     public
    //     startPresale
    // {
    //     vm.startPrank(ALICE);
    //     usdc.approve(address(presale), 100_000e6);

    //     presale.deposit(ALICE, 100_000e6, bytes32(0));

    //     //create a referrer ID
    //     bytes32 refId = presale.createReferrerId();

    //     vm.stopPrank();

    //     vm.startPrank(BOB);
    //     usdc.approve(address(presale), 100_000e6);

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             SafeYieldPresale
    //                 .SAFE_YIELD_REFERRER_MAX_WALLET_ALLOCATION_EXCEEDED
    //                 .selector
    //         )
    //     );

    //     presale.deposit(BOB, 100_000e6, refId);
    //     vm.stopPrank();
    // }

    function testBuyTokensShouldFailIfPresaleIsPaused() public pause {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));

        presale.deposit(ALICE, 1_000e6, bytes32(0));
    }

    function testRedeemUsdcCommissionShouldFailIfPaused() public pause {
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        presale.redeemUsdcCommission();
    }

    function testBuySafeTokensWithNoReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_500e6);
        console.logBytes32(bytes32(0));
        console.log(1500e6);
        presale.deposit(
            ALICE,
            1_500e6,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
    }
    //1500000000

    function testBuySafeTokensWithReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(ALICE, 1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(BOB, 1_000e6, refId);

        skip(1 minutes);

        //alice redeem usdc
        vm.startPrank(ALICE);
        presale.redeemUsdcCommission();
        vm.stopPrank();

        //end presale
        vm.startPrank(protocolAdmin);
        presale.endPresale();
        vm.stopPrank();

        uint128 safeTokens = presale.getTotalSafeTokensOwed(ALICE);

        //claim safe tokens
        vm.startPrank(ALICE);
        sToken.approve(address(staking), safeTokens);
        presale.claimSafeTokens();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz__testBuySafeTokensWithNoReferrer(
        uint256 usdcAmount
    ) public startPresale {
        usdcAmount = bound(usdcAmount, 1_000e6, 10_000e6);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), usdcAmount);

        presale.deposit(ALICE, uint128(usdcAmount), bytes32(0));

        uint256 safeTokensBought = (usdcAmount * 1e18) / 1e6;

        //assertions
        assertEq(usdc.balanceOf(address(presale)), usdcAmount);
        assertEq(presale.getTotalSafeTokensOwed(ALICE), safeTokensBought);
    }

    function testFuzz__testBuySafeTokensWithReferrer(
        uint256 usdcAmount
    ) public startPresale {
        usdcAmount = bound(usdcAmount, 1_000e6, 10_000e6);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), usdcAmount);

        presale.deposit(ALICE, uint128(usdcAmount), bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), usdcAmount);

        presale.deposit(BOB, uint128(usdcAmount), refId);

        vm.stopPrank();

        uint256 safeTokensBought = (usdcAmount * 1e18) / 1e6;
        uint256 referrerSafeCommission = (safeTokensBought * 5_00) / 1e4;
        uint256 referrerUSdcCommission = (usdcAmount * 5_00) / 1e4;

        //assertions
        assertEq(usdc.balanceOf(address(presale)), usdcAmount * 2);
        assertEq(
            presale.getTotalSafeTokensOwed(ALICE),
            safeTokensBought + referrerSafeCommission
        );
        assertEq(presale.getTotalSafeTokensOwed(BOB), safeTokensBought);

        //referrer claim usdc
        vm.prank(ALICE);
        presale.redeemUsdcCommission();

        assertEq(
            usdc.balanceOf(address(presale)),
            (usdcAmount * 2) - referrerUSdcCommission
        );

        vm.prank(protocolAdmin);
        presale.endPresale();

        uint256 aliceOwedSafeTokens = presale.getTotalSafeTokensOwed(ALICE);

        vm.prank(ALICE);
        presale.claimSafeTokens();

        assertEq(safeToken.balanceOf(ALICE), aliceOwedSafeTokens);
    }
}
