// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { PreSaleState } from "src/types/SafeTypes.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";

contract SafeYieldPresaleTest is SafeYieldBaseTest {
    /*//////////////////////////////////////////////////////////////
                              NORMAL TESTS
    //////////////////////////////////////////////////////////////*/

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
        uint256 referrerCommissionUsdc = presale.referrerCommissionUsdcBps();
        uint256 referrerCommissionSafe = presale.referrerCommissionSafeTokenBps();

        assertEq(referrerCommissionUsdc, 5_00);
        assertEq(referrerCommissionSafe, 5_00);
    }

    function testPresaleNotStarted() public view {
        assertEq(uint8(presale.currentPreSaleState()), uint8(PreSaleState.NotStarted));
    }

    function testCreateReferrerId() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        bytes32 refId = presale.createReferrerId();

        assertEq(refId, keccak256(abi.encodePacked(ALICE)));
    }

    function testCreateReferrerIdShouldFailIfCallerHasNotInvested() public startPresale {
        vm.expectRevert(SafeYieldPresale.SAFE_YIELD_ZERO_BALANCE.selector);
        presale.createReferrerId();
        vm.stopPrank();
    }

    function testBuyShouldFailIfPresaleNotStarted() public {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(SafeYieldPresale.SAFE_YIELD_PRESALE_NOT_LIVE.selector);
        presale.deposit(1_000e6, bytes32(0));
    }

    function testBuySafeTokensShouldFailPotentialSafeTokensLessThanMinTokenAllocation() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 999e6);

        vm.expectRevert(SafeYieldPresale.SAFE_YIELD_BELOW_MIN_ALLOCATION.selector);

        presale.deposit(999e6, bytes32(0));
    }

    function testBuyTokensShouldFailIfReferrerIdIsInvalid() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(SafeYieldPresale.SAFE_YIELD_UNKNOWN_REFERRER.selector);

        presale.deposit(1_000e6, keccak256(abi.encode("invalid_referrer_id")));
    }

    function testBuyTokesShouldFailIfReferrerIsSameAsBuyer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(SafeYieldPresale.SAFE_YIELD_REFERRAL_TO_SELF.selector);

        presale.deposit(1_000e6, refId);
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanPreSaleCapButLessThanMaxWalletAlloc() public startPresale {
        /**
         * Safe Tokens sold to 19 users = 1_900_000e18
         */
        test_mintUsdcAndDepositMultipleAddresses(20);

        /**
         * After minting to 19 users, 100_000e6 USDC is left to fill the presale cap
         */
        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());

        uint256 aliceUsdcBalancePrior = usdc.balanceOf(ALICE);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);
        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();
        /**
         * After Alice buys 1_000e6 safe tokens, the remaining safe tokens available 99_000e18
         */
        console.log("Safe Tokens Remaining After Alice Buys", presale.safeTokensAvailable());
        vm.stopPrank();

        console.log("usdc Raised:", presale.totalUsdcRaised());

        /**
         * Now Bob wants to 110_000e18 safe tokens which is more than the remaining safe tokens available
         * So Bob should only be able to buy 99_000e18 safe tokens and get refunded. But since Bob has a referrer
         * Bob will share remaining safe tokens with the referrer proportionally. so alice will get less than the 99_000e18
         * safe tokens.
         */
        vm.startPrank(BOB);
        usdc.approve(address(presale), 110_000e6);

        uint256 bobUsdcBalancePrior = usdc.balanceOf(BOB);
        console.log("Bob USDC Balance Prior", bobUsdcBalancePrior);
        presale.deposit(110_000e6, refId);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(BOB);
        console.log("Bob USDC Balance After", bobUsdcBalanceAfter);

        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(ALICE);

        //assertions
        assertGt(bobUsdcBalanceAfter, 0);
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalancePrior - 1_000e6, "Alice USDC Balance should be 1_000e6 less");
        assertEq(usdc.balanceOf(address(presale)), 2_000_000e6, "USDC Balance of Presale should be 2_000_000e6");
        assertEq(presale.safeTokensAvailable(), 0, "Safe Tokens Available should be 0");
        assertEq(
            presale.totalUsdcRaised(),
            2_000_000e6 - presale.totalRedeemableReferrerUsdc(),
            "Total USDC Raised should be 2_000_000e6 - totalRedeemableReferrerUsdc"
        );
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanPresaleCapAndAlsoMoreThanMaxWalletAlloc() public startPresale {
        test_mintUsdcAndDepositMultipleAddresses(19);

        /**
         * After minting to 19 users, 200_000e6 USDC is left to fill the presale cap
         */
        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());
        assertEq(presale.safeTokensAvailable(), 200_000e18);

        /**
         * Alice wants buy 110_000e6 USDC worth of safe tokens ,
         * which is more than her max wallet allocation of 100_000e18 safe tokens, assuming price
         * of 1 safe token is 1 USDC, therefore Alice should only be able to buy 100_000e18 safe tokens
         * Alice should also be refunded the remaining 10_000e6 USDC
         */
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 110_000e6);

        uint256 aliceUsdcBalancePrior = usdc.balanceOf(ALICE);
        presale.deposit(110_000e6, bytes32(0));
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(ALICE);

        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalancePrior - 100_000e6);
        assertEq(usdc.balanceOf(address(presale)), 1_900_000e6);
        assertEq(presale.getTotalSafeTokensOwed(ALICE), 100_000e18);
        assertEq(presale.safeTokensAvailable(), 100_000e18);
        assertEq(presale.totalUsdcRaised(), 1_900_000e6);
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanMaxPerWalletWithNoReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 110_000e6);

        uint256 aliceUsdcBalancePrior = usdc.balanceOf(ALICE);
        presale.deposit(110_000e6, bytes32(0));
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(ALICE);

        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalancePrior - 100_000e6);
        assertEq(usdc.balanceOf(address(presale)), 100_000e6);
        assertEq(presale.getTotalSafeTokensOwed(ALICE), 100_000e18);
    }

    function testBuyTokensWhenBuyerWantsToBuySameNumberOfTokensAvailable() public startPresale {
        test_mintUsdcAndDepositMultipleAddresses(20);

        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());
        //100_000 00 00 00 00 00 00 00 00 00
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 100_000e6);

        //103_950 00 00 00 00 00 00 00 00 00
        //4_950 00 00 00 00 00 00 00 00 00
        //99_000 00 00 00 00 00 00 00 00 00

        uint256 bobUsdcBalancePrior = usdc.balanceOf(BOB);
        presale.deposit(99_000e6, refId);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(BOB);

        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanMaxPerWalletWithReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 110_000e6);

        uint256 bobUsdcBalancePrior = usdc.balanceOf(BOB);
        presale.deposit(110_000e6, refId);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(BOB);

        // assertEq(bobUsdcBalanceAfter, bobUsdcBalancePrior - 100_000e6);
        // assertEq(usdc.balanceOf(address(presale)), 101_000e6);
        // assertEq(presale.getTotalSafeTokensOwed(BOB), 100_000e18);
        // assertEq(presale.getTotalSafeTokensOwed(ALICE), 1_000e18);
    }

    function testBuySafeTokensWhenBuyerWantsToBuyMoreThanThePreSaleCAPWithReferrer() public startPresale {
        vm.startPrank(protocolAdmin);
        usdc.mint(ALICE, 2_000_000e6);
        vm.stopPrank();

        vm.startPrank(ALICE);
        usdc.approve(address(presale), 2_000_000e6);

        presale.deposit(100_000e6, bytes32(0));
    }

    function test_claimTokensShouldRevertIfPreSaleNotEnded() public {
        vm.expectRevert(abi.encodeWithSelector(SafeYieldPresale.SAFE_YIELD_PRESALE_NOT_ENDED.selector));
        presale.claimSafeTokens();
    }

    // function testBuyTokensShouldFailIfReferrersInvestmentPlusCommissionsExceedMaxTokenAllocation()
    //     public
    //     startPresale
    // {
    //     vm.startPrank(ALICE);
    //     usdc.approve(address(presale), 100_000e6);

    //     presale.deposit( 100_000e6, bytes32(0));

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

    //     presale.deposit( 100_000e6, refId);
    //     vm.stopPrank();
    // }

    function testBuyTokensShouldFailIfPresaleIsPaused() public pause {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(EnforcedPause.selector);

        presale.deposit(1_000e6, bytes32(0));
    }

    function testRedeemUsdcCommissionShouldFailIfPaused() public pause {
        vm.startPrank(ALICE);
        vm.expectRevert(EnforcedPause.selector);
        presale.redeemUsdcCommission();
    }

    function testBuySafeTokensWithNoReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_500e6);

        presale.deposit(1_500e6, bytes32(0));
    }
    //1500000000

    function testBuySafeTokensWithReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, refId);

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
        presale.claimSafeTokens();
        vm.stopPrank();
    }

    function testBuySafeWithMultipleReferrers() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 10_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 10_000e6);

        presale.deposit(1_000e6, refId);

        bytes32 bobRefId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(CHARLIE);
        usdc.approve(address(presale), 10_000e6);

        console.log("Charlie bought");
        presale.deposit(1_000e6, refId);
        console.log("Charlie bought again");
        presale.deposit(1_000e6, refId);

        vm.stopPrank();

        vm.startPrank(BOB);

        presale.deposit(1_000e6, refId);

        vm.stopPrank();

        vm.startPrank(ALICE);

        presale.deposit(1_000e6, bobRefId);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz__testBuySafeTokensWithNoReferrer(uint256 usdcAmount) public startPresale {
        usdcAmount = bound(usdcAmount, 1_000e6, 10_000e6);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), usdcAmount);

        presale.deposit(uint128(usdcAmount), bytes32(0));

        uint256 safeTokensBought = (usdcAmount * 1e18) / 1e6;

        //assertions
        assertEq(usdc.balanceOf(address(presale)), usdcAmount);
        assertEq(presale.getTotalSafeTokensOwed(ALICE), safeTokensBought);
    }

    function testFuzz__testBuySafeTokensWithReferrerMultipleOps(uint256 usdcAmount) public startPresale {
        usdcAmount = bound(usdcAmount, 1_000e6, 10_000e6);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), usdcAmount);

        presale.deposit(uint128(usdcAmount), bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.createReferrerId();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), usdcAmount);

        presale.deposit(uint128(usdcAmount), refId);

        vm.stopPrank();

        uint256 safeTokensBought = (usdcAmount * 1e18) / 1e6;
        uint256 referrerSafeCommission = (safeTokensBought * 5_00) / 1e4;
        uint256 referrerUSdcCommission = (usdcAmount * 5_00) / 1e4;

        //assertions
        assertEq(usdc.balanceOf(address(presale)), usdcAmount * 2);
        assertEq(presale.getTotalSafeTokensOwed(ALICE), safeTokensBought + referrerSafeCommission);
        assertEq(presale.getTotalSafeTokensOwed(BOB), safeTokensBought);

        //referrer claim usdc
        vm.prank(ALICE);
        presale.redeemUsdcCommission();

        assertEq(usdc.balanceOf(address(presale)), (usdcAmount * 2) - referrerUSdcCommission);

        vm.prank(protocolAdmin);
        presale.endPresale();

        uint256 aliceOwedSafeTokens = presale.getTotalSafeTokensOwed(ALICE);

        /**
         * Alice can claim after the presale ends
         */
        vm.prank(ALICE);
        presale.claimSafeTokens();

        assertEq(safeToken.balanceOf(ALICE), aliceOwedSafeTokens);
    }

    function test_mintUsdcAndDepositMultipleAddresses(uint256 numberOfAddress) internal {
        /**
         * so say numberOfAddress is 20 then we will mint 100_000e6 USDC to each address(ie 19 addresses)
         * and deposit 100_000e6 USDC to the presale contract , so the total USDC deposited
         * will be 1_900_000e6 USDC , 100_000e6 will be left to fill the presale cap.
         * fill the Presale cap we can numberOfAddresses should be 21.(ie 20 users).
         */
        console.log("Safe Tokens Available", presale.safeTokensAvailable());
        for (uint256 i = 1; i < numberOfAddress; i++) {
            vm.prank(protocolAdmin);
            usdc.mint(address(uint160(i)), 100_000e6);

            vm.startPrank(address(uint160(i)));
            usdc.approve(address(presale), 100_000e6);
            presale.deposit(uint128(100_000e6), bytes32(0));
            vm.stopPrank();
        }
    }
}
