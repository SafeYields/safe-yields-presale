// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldVesting } from "src/SafeYieldVesting.sol";
import { PreSaleState, VestingSchedule } from "src/types/SafeTypes.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";

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

    function testShouldFailIfEitherCommissionIsSetAboveBPS_MAX() public {
        vm.startPrank(protocolAdmin);

        vm.expectRevert(SafeYieldPresale.SYPS__INVALID_REFER_COMMISSION_PERCENTAGE.selector);
        presale.setReferrerCommissionBps(10_000, 10_000);
    }

    function testShouldFailIfInvalidAddressSetAsMultiSig() public {
        vm.startPrank(protocolAdmin);

        vm.expectRevert(SafeYieldPresale.SYPS__INVALID_ADDRESS.selector);
        presale.setProtocolMultisig(address(0));
    }

    function testMultiSigSetCorrectly() public {
        vm.startPrank(protocolAdmin);

        presale.setProtocolMultisig(makeAddr("Presale Multisig"));

        assertEq(presale.protocolMultisig(), makeAddr("Presale Multisig"));
    }

    function testSetAllocationIsSetCorrectly() public {
        vm.startPrank(protocolAdmin);

        presale.setAllocationsPerWallet(1_500e18, uint128(PRE_SALE_MAX_SUPPLY));

        assertEq(presale.minAllocationPerWallet(), 1_500e18);
        assertEq(presale.maxAllocationPerWallet(), uint128(PRE_SALE_MAX_SUPPLY));
    }

    function testShouldFailTransferRemainingSAYDuringPresaleLIVE() public {
        vm.startPrank(protocolAdmin);

        vm.expectRevert(SafeYieldPresale.SYPS__PRESALE_LIVE.selector);
        presale.transferRemainingSayToken(makeAddr("New Receiver"));
    }

    function testTransferRemainingSAY() public startEndPresale {
        vm.startPrank(protocolAdmin);

        uint256 presaleSAYBalance = safeToken.balanceOf(address(presale));

        presale.transferRemainingSayToken(makeAddr("New Receiver"));

        assertEq(safeToken.balanceOf(makeAddr("New Receiver")), presaleSAYBalance);
    }

    function testSetNewConfig() public {
        vm.startPrank(protocolAdmin);

        presale.setConfig(makeAddr("NewConfig"));

        assertEq(address(presale.safeYieldConfigs()), makeAddr("NewConfig"));
    }

    function testSetReferrerCommissionBpsCorrectly() public {
        vm.startPrank(protocolAdmin);

        presale.setReferrerCommissionBps(200, 300);

        assertEq(presale.referrerCommissionSafeTokenBps(), 300);
        assertEq(presale.referrerCommissionUsdcBps(), 200);
    }

    function testSetTokenPriceCorrectly() public {
        vm.startPrank(protocolAdmin);

        presale.setTokenPrice(0.6e18);

        assertEq(presale.tokenPrice(), 0.6e18);
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

        bytes32 refId = presale.getReferrerID();

        assertEq(refId, keccak256(abi.encodePacked(ALICE)));
    }

    function testBuyShouldFailIfPresaleNotStarted() public {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(SafeYieldPresale.SYPS__PRESALE_NOT_LIVE.selector);
        presale.deposit(1_000e6, bytes32(0));
    }

    function testBuySafeTokensShouldFailPotentialSafeTokensLessThanMinTokenAllocation() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 999e6);

        vm.expectRevert(SafeYieldPresale.SYPS__BELOW_MIN_ALLOCATION.selector);

        presale.deposit(999e6, bytes32(0));
    }

    function testBuyTokensShouldFailIfReferrerIdIsInvalid() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(SafeYieldPresale.SYPS__UNKNOWN_REFERRER.selector);

        presale.deposit(1_000e6, keccak256(abi.encode("invalid_referrer_id")));
    }

    function testBuyTokesShouldFailIfReferrerIsSameAsBuyer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.getReferrerID();

        usdc.approve(address(presale), 1_000e6);

        vm.expectRevert(SafeYieldPresale.SYPS__REFERRAL_TO_SELF.selector);

        presale.deposit(1_000e6, refId);
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanPreSaleCapButLessThanMaxWalletAlloc() public startPresale {
        /**
         * Safe Tokens sold to 19 users = 1_900_000e18
         */
        test_mintUsdcAndDepositMultipleAddresses(20, 100_000e6, false);

        /**
         * After minting to 19 users, 100_000e6 USDC is left to fill the presale cap
         */
        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());

        uint256 aliceUsdcBalancePrior = usdc.balanceOf(ALICE);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);
        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.getReferrerID();
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
        assertEq(
            usdc.balanceOf(address(presale)),
            presale.totalReferrersUsdc(),
            "USDC Balance of Presale should be equal to total redeemable referrer USDC"
        );
        assertEq(presale.safeTokensAvailable(), 0, "Safe Tokens Available should be 0");
        assertEq(
            presale.totalUsdcRaised(),
            2_000_000e6 - presale.totalReferrersUsdc(),
            "Total USDC Raised should be 2_000_000e6 - totalReferrersUsdc"
        );
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanPresaleCapAndAlsoMoreThanMaxWalletAlloc() public startPresale {
        test_mintUsdcAndDepositMultipleAddresses(19, 100_000e6, false);

        /**
         * After minting to 19 users, 200_000e6 USDC is left to fill the presale cap
         */
        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());
        assertEq(presale.safeTokensAvailable(), 200_000e18);

        /**
         * Alice wants buy 210_000e6 USDC worth of safe tokens and theres is only 200_000e18 left,
         * which is more than her max wallet allocation of 2_000_000e18 safe tokens, assuming price
         * of 1 safe token is 1 USDC, therefore Alice should only be able to buy 200_000e18 safe tokens
         * Alice should also be refunded the remaining 10_000e6 USDC
         */
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 210_000e6);

        uint256 aliceUsdcBalancePrior = usdc.balanceOf(ALICE);
        presale.deposit(210_000e6, bytes32(0));
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(ALICE);
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalancePrior - 200_000e6);
        assertEq(usdc.balanceOf(address(presale)), presale.totalReferrersUsdc());
        assertEq(presale.getTotalSafeTokensOwed(ALICE), 200_000e18);
        assertEq(presale.safeTokensAvailable(), 0);
        assertEq(presale.totalUsdcRaised(), 2_000_000e6);
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanMaxPerWalletWithNoReferrer() public startPresale {
        vm.startPrank(ALICE);
        //Max per Wallet is 2_000_000e18 that is if price is 1e18
        usdc.approve(address(presale), 2_001_000e6);

        uint256 aliceUsdcBalancePrior = usdc.balanceOf(ALICE);
        presale.deposit(2_001_000e6, bytes32(0));
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(ALICE);

        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalancePrior - 2_000_000e6);
        assertEq(usdc.balanceOf(address(presale)), 0);
        assertEq(presale.getTotalSafeTokensOwed(ALICE), 2_000_000e18);
    }

    function testBuyTokensWhenBuyerWantsToBuySameNumberOfTokensAvailable() public startPresale {
        test_mintUsdcAndDepositMultipleAddresses(20, 100_000e6, false);

        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());
        //100_000 00 00 00 00 00 00 00 00 00
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.getReferrerID();

        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 100_000e6);

        uint256 bobUsdcBalancePrior = usdc.balanceOf(BOB);
        presale.deposit(99_000e6, refId);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(BOB);

        /**
         * 5% of the Bob USDC deposited
         */
        uint256 aliceReferralUsdcCommission = (99_000e6 * 500) / 10_000;
        console.log("aliceReferralUsdcCommission", aliceReferralUsdcCommission);
        console.log("Safe Tokens Remaining After selling to 19 users", presale.safeTokensAvailable());

        assertEq(bobUsdcBalanceAfter, bobUsdcBalancePrior - 99_000e6);
        assertEq(usdc.balanceOf(address(presale)), aliceReferralUsdcCommission);

        /**
         * since bob is buying the remaining safe left,
         * buyer and referrer
         * share the remaining safe tokens.
         * BuyerBps = 10_000(100%)
         * referrer = 500 (5%)
         * totalBps = 10_500
         */
        uint256 bobBps = 10_000;
        uint256 aliceBps = 500;

        uint256 bobCalculatedSafeOwed = (99_000e18 * bobBps) / (bobBps + aliceBps);
        uint256 aliceSafeCommissionOwed = (99_000e18 * aliceBps) / (bobBps + aliceBps);

        assertApproxEqAbs(presale.getTotalSafeTokensOwed(BOB), bobCalculatedSafeOwed, 1);
        assertApproxEqAbs(presale.getTotalSafeTokensOwed(ALICE), aliceSafeCommissionOwed + 1_000e18, 1);
    }

    function testBuyTokensWhenBuyerWantsToBuyMoreThanMaxPerWalletWithReferrer() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_000e6);

        presale.deposit(1_000e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.getReferrerID();

        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 2_000_000e6);

        uint256 bobUsdcBalancePrior = usdc.balanceOf(BOB);
        presale.deposit(2_000_000e6, refId);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(BOB);

        assertEq(bobUsdcBalanceAfter, bobUsdcBalancePrior - 1_999_000e6);
        assertEq(usdc.balanceOf(address(presale)), presale.totalReferrersUsdc());

        /**
         * 5% of the Bob USDC deposited
         */

        /**
         * since bob is buying the remaining safe left,
         * buyer and referrer
         * share the remaining safe tokens.
         * BuyerBps = 10_000(100%)
         * referrer = 500 (5%)
         * totalBps = 10_500
         */
        uint256 bobBps = 10_000;
        uint256 aliceBps = 500;

        uint256 bobCalculatedSafeOwed = (1_999_000e18 * bobBps) / (bobBps + aliceBps);
        uint256 aliceSafeCommissionOwed = (1_999_000e18 * aliceBps) / (bobBps + aliceBps);

        assertApproxEqAbs(presale.getTotalSafeTokensOwed(BOB), bobCalculatedSafeOwed, 1);
        assertApproxEqAbs(presale.getTotalSafeTokensOwed(ALICE), aliceSafeCommissionOwed + 1_000e18, 1);
    }

    function testBuySafeTokensWhenBuyerWantsToBuyMoreThanThePreSaleCAPWithReferrer() public startPresale {
        vm.startPrank(protocolAdmin);
        usdc.mint(ALICE, 2_000_000e6);
        usdc.mint(BOB, 2_000_000e6);
        vm.stopPrank();

        vm.startPrank(ALICE);
        usdc.approve(address(presale), 2_000_000e6);

        presale.deposit(100_317e6, bytes32(0));

        bytes32 aliceReferrerId = presale.getReferrerID();
        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 2_000_000e6);
        presale.deposit(2_000_000e6, aliceReferrerId);
        vm.stopPrank();

        assertTrue(
            presale.totalUsdcRaised() + presale.totalReferrersUsdc() == 2_000_000e6,
            "Total USDC Raised should be 2_000_000e6"
        );
        assertTrue(presale.safeTokensAvailable() == 0, "Safe Tokens Available should be 0");
    }

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

    function testBuySafeTokensWithReferrerAndClaimSafeTokensFromVesting() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 1_500e6);

        presale.deposit(1_500e6, bytes32(0));

        //create a referrer ID
        bytes32 refId = presale.getReferrerID();

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

        skip(30 * 24 * 60 * 60 seconds); //1 month);

        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        /**
         * alice claims after 1.5 month
         */
        skip(45 * 24 * 60 * 60 seconds); //45 days

        uint256 timeStamp = 45 * 24 * 60 * 60 seconds;

        //claim safe tokens
        uint256 aliceCommissionFromBOB = (500 * 1_000e18) / 10_000;

        uint256 aliceTotalStaked = aliceCommissionFromBOB + 1_500e18;

        uint256 monthsElapsed = (timeStamp * 10_000) / safeYieldVesting.ONE_MONTH();

        console.log("Month elapsed - t", monthsElapsed);

        uint256 unlockedPercentage = (monthsElapsed * 2_000) / 10_000;

        console.log("unlockedPercentage - t", unlockedPercentage);

        uint256 aliceCalculatedSafe = (unlockedPercentage * aliceTotalStaked) / 10_000;

        vm.startPrank(ALICE);
        staking.unstakeVestedTokens();
        vm.stopPrank();

        assertEq(safeToken.balanceOf(ALICE), aliceCalculatedSafe);
    }

    function testBuySafeWithMultipleReferrers() public startPresale {
        vm.startPrank(ALICE);
        usdc.approve(address(presale), 10_000e6);
        presale.deposit(1_000e6, bytes32(0));
        bytes32 aliceRefId = presale.getReferrerID();
        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), 10_000e6);
        presale.deposit(1_000e6, aliceRefId);
        bytes32 bobRefId = presale.getReferrerID();
        vm.stopPrank();

        vm.startPrank(CHARLIE);
        usdc.approve(address(presale), 10_000e6);
        presale.deposit(1_500e6, aliceRefId);
        presale.deposit(1_500e6, bobRefId);
        vm.stopPrank();

        vm.startPrank(ALICE);
        presale.deposit(1_000e6, bobRefId);
        vm.stopPrank();

        uint256 aliceSafeCommissionFromBob = (500 * 1_000e18) / 10_000;
        uint256 aliceSafeCommissionFromCharlie = (500 * 1_500e18) / 10_000;
        assertEq(
            presale.getTotalSafeTokensOwed(ALICE),
            2_000e18 + aliceSafeCommissionFromBob + aliceSafeCommissionFromCharlie
        );

        uint256 bobSafeCommissionFromCharlie = (500 * 1_500e18) / 10_000;
        uint256 bobSafeCommissionFromAlice = (500 * 1_000e18) / 10_000;

        assertEq(
            presale.getTotalSafeTokensOwed(BOB), 1_000e18 + bobSafeCommissionFromCharlie + bobSafeCommissionFromAlice
        );

        assertEq(presale.getTotalSafeTokensOwed(CHARLIE), 3_000e18);
    }

    function testBuySafeAfterIDOStarts() public startPresale { }

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
        assertEq(usdc.balanceOf(address(presale)), presale.totalReferrersUsdc());
        assertEq(presale.getTotalSafeTokensOwed(ALICE), safeTokensBought);
    }

    function testFuzz__testBuySafeTokensWithReferrerMultipleOps(uint256 usdcAmount) public startPresale {
        usdcAmount = bound(usdcAmount, 1_000e6, 100_000e6);

        vm.startPrank(ALICE);
        usdc.approve(address(presale), usdcAmount);
        presale.deposit(uint128(usdcAmount), bytes32(0));

        //create a referrer ID
        bytes32 aliceRefId = presale.getReferrerID();
        vm.stopPrank();

        vm.startPrank(BOB);
        usdc.approve(address(presale), usdcAmount);
        presale.deposit(uint128(usdcAmount), aliceRefId);
        vm.stopPrank();

        uint256 safeTokensBought = (usdcAmount * 1e18) / 1e6;
        uint256 referrerSafeCommission = (safeTokensBought * 5_00) / 1e4;
        uint256 referrerUSdcCommission = (usdcAmount * 5_00) / 1e4;

        //assertions
        assertEq(usdc.balanceOf(address(presale)), presale.totalReferrersUsdc());
        assertEq(presale.getTotalSafeTokensOwed(ALICE), safeTokensBought + referrerSafeCommission);
        assertEq(presale.getTotalSafeTokensOwed(BOB), safeTokensBought);
        assertEq(referrerUSdcCommission, presale.totalReferrersUsdc());

        //referrer claim usdc
        vm.prank(ALICE);
        presale.redeemUsdcCommission();

        assertEq(usdc.balanceOf(address(presale)), 0);

        vm.prank(protocolAdmin);
        presale.endPresale();

        skip(30 * 24 * 60 * 60 seconds); //1 month);

        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        /**
         * Bob can start claiming after presale ends
         */
        skip(2 * 30 * 24 * 60 * 60 seconds); //2 months;
        vm.prank(BOB);

        staking.unstakeVestedTokens();

        uint256 bobFirstMonthCalculated = (2_000 * safeTokensBought) / 10_000;
        uint256 bobSecondMonthCalculated = (2_000 * safeTokensBought) / 10_000;

        assertEq(safeToken.balanceOf(BOB), bobFirstMonthCalculated + bobSecondMonthCalculated);

        /**
         * Alice can start claiming after presale ends and
         * after 3 months
         */
        skip(30 * 24 * 60 * 60 seconds); //3  months;
        vm.prank(ALICE);
        staking.unstakeVestedTokens();

        /**
         * 20% of SAFE tokens are unlocked each month.
         * In the first month, Alice receives the full 20%.
         * In the second month, she receives full (20%).
         * In the third month, she receives full (20%).
         * Example: If Alice has 1,500 SAFE tokens:
         *      Month 1: 20% of 1,500 = 300
         *      Month 2: 20% of 1,500 = 300
         *      Month 3: 20& of 1_500 = 300
         *      Total: 300 + 300 + 300 = 900 SAFE tokens.
         */
        uint256 aliceSafeCommissionFromBob = (500 * safeTokensBought) / 10_000;
        uint256 aliceTotalVested = aliceSafeCommissionFromBob + safeTokensBought;

        assertEq(presale.getTotalSafeTokensOwed(ALICE), aliceTotalVested);

        uint256 aliceFirstMonthCalculated = (2_000 * aliceTotalVested) / 10_000;
        uint256 aliceSecondMonthCalculated = (2_000 * aliceTotalVested) / 10_000;
        uint256 aliceThirdMonthCalculated = (2_000 * aliceTotalVested) / 10_000;

        assertEq(
            safeToken.balanceOf(ALICE),
            aliceFirstMonthCalculated + aliceSecondMonthCalculated + aliceThirdMonthCalculated
        );
    }

    function test_mintUsdcAndDepositMultipleAddresses(uint256 numberOfAddress, uint256 amount, bool isSwitchRef)
        internal
    {
        /**
         * so say numberOfAddress is 20 then we will mint 100_000e6 USDC to each address(ie 19 addresses)
         * and deposit 100_000e6 USDC to the presale contract , so the total USDC deposited
         * will be 1_900_000e6 USDC , 100_000e6 will be left to fill the presale cap.
         * fill the Presale cap we can numberOfAddresses should be 21.(ie 20 users).
         */
        uint256 counter;
        for (uint256 i = 1; i < numberOfAddress; i++) {
            vm.prank(protocolAdmin);
            usdc.mint(address(uint160(i)), amount);
            /**
             * so we can sell out the tokens
             */
            if (presale.safeTokensAvailable() == 0) return;

            bytes32 refId = bytes32(0);

            if (isSwitchRef) {
                if (counter == 10) {
                    //create a referrer ID
                    vm.prank(address(uint160(i - 1)));
                    refId = presale.getReferrerID();

                    counter = 0;
                }
            }
            vm.startPrank(address(uint160(i)));
            usdc.approve(address(presale), amount);
            presale.deposit(uint128(amount), refId);
            vm.stopPrank();
            counter++;
        }
    }
}
