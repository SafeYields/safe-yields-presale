// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { PreSaleState } from "src/types/SafeTypes.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SafeYieldStakingTest is SafeYieldBaseTest {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;
    /*//////////////////////////////////////////////////////////////
                              NORMAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testIfSafeTokensAreSetCorrectly() public view {
        assertEq(address(safeToken), address(staking.safeToken()));
    }

    function testIfsSafeTokensAreSetCorrectly() public view {
        assertEq(address(sToken), address(staking.sSafeToken()));
    }

    function testIfUsdcTokensAreSetCorrectly() public view {
        assertEq(address(usdc), address(staking.usdc()));
    }

    function testStakeForShouldFailIfPresaleIsLiveAndCallerIsNotPresale() public startPresale {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_STAKING_LOCKED.selector);
        vm.prank(ALICE);
        staking.stakeFor(ALICE, 1_000e18);
    }

    function testStakeForShouldFailIfStakeAmountIsLessThanMin() public startEndPresale {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_INVALID_STAKE_AMOUNT.selector);
        vm.startPrank(ALICE);
        staking.stakeFor(ALICE, 9e17);
        vm.stopPrank();
    }

    function testUnStakeForShouldFailIfUnStakeAmountIsLessThanMin() public startEndPresale {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_INVALID_STAKE_AMOUNT.selector);
        vm.startPrank(ALICE);
        staking.unStake(ALICE, 9e17);
        vm.stopPrank();
    }

    function testUnStakeShouldFailIfUserHasNoStake() public startEndPresale {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_INSUFFICIENT_STAKE.selector);
        vm.startPrank(ALICE);
        staking.unStake(ALICE, 1_000e18);
        vm.stopPrank();
    }

    function testStakeShouldRevertIfPreSaleIsLiveAndCallerIsNotAdmin() public startEndPresale {
        vm.prank(protocolAdmin);
        presale.startPresale();
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_STAKING_LOCKED.selector);
        vm.prank(NOT_ADMIN);
        staking.stakeFor(NOT_ADMIN, 1_000e18);
    }

    function testClaimUsdcRewards() public startEndPresale {
        /**
         * @dev since its normal rewards distribution, Usdc rewards will be distributed
         * staking rewards gets 60% of the USDC rewards from the distributor.
         * 10_000e6 USDC is minted to the distributor, so
         * 60% of 10_000e6 = 6_000e6 USDC will be distributed to the staking contract
         * since both alice staked 2_000e18 and bob staked 1_000e18, they will get
         * @notice : example calculation
         * Alice gets 2_000e18 / 3_000e18 * 6_000e6 = 4_000e6
         * Bob gets 1_000e18 / 3_000e18 * 6_000e6 = 2_000e6
         */
        _transferSafeTokens(ALICE, 10_000e18);

        _transferSafeTokens(BOB, 10_000e18);

        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(ALICE, 2_000e18);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(BOB, 1_000e18);
        vm.stopPrank();

        skip(5 minutes);
        (uint128 pendingUsdcRewardsAlice,) = staking.calculatePendingRewards(address(ALICE));

        (uint128 pendingUsdcRewardsBob,) = staking.calculatePendingRewards(address(BOB));

        console.log("Pending rewards Alice: ", pendingUsdcRewardsAlice);
        console.log("Pending rewards Bob: ", pendingUsdcRewardsBob);

        uint256 aliceUsdcBalanceBefore = usdc.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.claimRewards();
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(address(ALICE));

        uint256 bobUsdcBalanceBefore = usdc.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.claimRewards();
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(address(BOB));

        (uint128 pendingUsdcRewardsAliceAfter,) = staking.calculatePendingRewards(address(ALICE));
        (uint128 pendingUsdcRewardsBobAfter,) = staking.calculatePendingRewards(address(BOB));

        //assertions
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalanceBefore + pendingUsdcRewardsAlice);
        assertEq(bobUsdcBalanceAfter, bobUsdcBalanceBefore + pendingUsdcRewardsBob);
        assertEq(pendingUsdcRewardsAliceAfter, 0);
        assertEq(pendingUsdcRewardsBobAfter, 0);
    }

    function testClaimSafeRewards() public startEndPresale {
        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();
        vm.stopPrank();

        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(ALICE, 2_000e18);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(BOB, 1_000e18);
        vm.stopPrank();

        /**
         * @dev since this during stake emission, Safe rewards will be distributed
         * staking rewards gets 35% value of the revenue rewards from the distributor.
         * 10_000e6 USDC is minted to the distributor, so 35% of 10_000e6 = 3_500e6 USDC , which
         * is used to transfer safe rewards to the staking contract per the value of the safe token
         * assuming the value of the safe token is 1e18, then 3_500e18 safe tokens will be transferred
         * to the staking contract. since  alice staked 2_000e18 and bob staked 1_000e18, they will get
         * @notice : example calculation
         * Alice gets 2_000e18 / 3_000e18 * 3_500e18 = 2_333e18
         * Bob gets 1_000e18 / 3_000e18 * 3_500e18 = 1_166e18
         */
        skip(5 minutes);
        (, uint128 pendingRewardsAlice) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingRewardsBob) = staking.calculatePendingRewards(address(BOB));

        console.log("Pending rewards Alice: ", pendingRewardsAlice);
        console.log("Pending rewards Bob: ", pendingRewardsBob);

        uint256 aliceUsdcBalanceBefore = safeToken.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.claimRewards();
        uint256 aliceUsdcBalanceAfter = safeToken.balanceOf(address(ALICE));

        uint256 bobUsdcBalanceBefore = safeToken.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.claimRewards();
        uint256 bobUsdcBalanceAfter = safeToken.balanceOf(address(BOB));

        //logs
        (, uint128 pendingSafeRewardsAliceAfter) = staking.calculatePendingRewards(address(ALICE));
        (, uint128 pendingSafeRewardsBobAfter) = staking.calculatePendingRewards(address(BOB));

        //assertions
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalanceBefore + pendingRewardsAlice);
        assertEq(bobUsdcBalanceAfter, bobUsdcBalanceBefore + pendingRewardsBob);
        assertEq(pendingSafeRewardsAliceAfter, 0);
        assertEq(pendingSafeRewardsBobAfter, 0);
    }

    function testStakeSafeTokens() public startEndPresale {
        vm.startPrank(address(distributor));
        safeToken.approve(address(staking), 10_000e18);

        staking.stakeFor(address(distributor), 1_000e18);

        assertEq(staking.totalStaked(), 1_000e18);
        assertEq(staking.getUserStake(address(distributor)).stakeAmount, 1_000e18);
    }

    function testUnStakeSafeTokensAndClaimUsdcRewards() public startEndPresale {
        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(ALICE, 2_000e18);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(BOB, 1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        (uint128 pendingUsdcRewardsAlice,) = staking.calculatePendingRewards(address(ALICE));

        (uint128 pendingUsdcRewardsBob,) = staking.calculatePendingRewards(address(BOB));

        console.log("Pending rewards Alice: ", pendingUsdcRewardsAlice);
        console.log("Pending rewards Bob: ", pendingUsdcRewardsBob);

        uint256 aliceUsdcBalanceBefore = usdc.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.unStake(ALICE, 1_000e18);
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(address(ALICE));

        uint256 bobUsdcBalanceBefore = usdc.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.unStake(BOB, 600e18);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(address(BOB));

        //logs
        console.log("Alice USDC balance before: ", aliceUsdcBalanceBefore);
        console.log("Alice USDC balance after: ", aliceUsdcBalanceAfter);

        console.log("Bob USDC balance before: ", bobUsdcBalanceBefore);
        console.log("Bob USDC balance after: ", bobUsdcBalanceAfter);

        //assertions
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalanceBefore + pendingUsdcRewardsAlice);
        assertEq(bobUsdcBalanceAfter, bobUsdcBalanceBefore + pendingUsdcRewardsBob);
        assertEq(staking.getUserStake(address(ALICE)).stakeAmount, 1_000e18);
        assertEq(sToken.balanceOf(address(ALICE)), 1_000e18);
        assertEq(staking.getUserStake(address(BOB)).stakeAmount, 400e18);
        assertEq(sToken.balanceOf(address(BOB)), 400e18);
    }

    function testStakeSafeTokensGetUsdcRewards() public startEndPresale {
        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        _transferSafeTokens(ALICE, 10_000e18);

        _transferSafeTokens(BOB, 10_000e18);

        skip(5 minutes);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(ALICE, 1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(BOB, 1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        (, uint128 pendingSafeRewardsAlice) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingSafeRewardsBOB) = staking.calculatePendingRewards(address(BOB));

        console.log("First Pending rewards Alice: ", pendingSafeRewardsAlice);
        console.log("First Pending rewards Bob: ", pendingSafeRewardsBOB);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);

        vm.prank(ALICE);
        staking.stakeFor(ALICE, 1_000e18);

        skip(5 minutes);

        vm.prank(BOB);
        staking.stakeFor(BOB, 1_000e18);

        skip(5 minutes);

        (, uint128 pendingSafeRewardsAlice2) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingSafeRewardsBOB2) = staking.calculatePendingRewards(address(BOB));

        console.log("Second Pending rewards Alice: ", pendingSafeRewardsAlice2);
        console.log("Second Pending rewards Bob: ", pendingSafeRewardsBOB2);
    }

    function testStakeSafeTokensGetSafeRewards() public startEndPresale {
        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();
        distributor.switchSharesPerPhase();
        vm.stopPrank();

        skip(5 minutes);
        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        _transferSafeTokens(ALICE, 10_000e18);

        _transferSafeTokens(BOB, 10_000e18);

        skip(5 minutes);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(ALICE, 1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(BOB, 1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        (, uint128 pendingRewardsAlice) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingRewardsBob) = staking.calculatePendingRewards(address(BOB));

        console.log("First Pending rewards Alice: ", pendingRewardsAlice);
        console.log("First Pending rewards Bob: ", pendingRewardsBob);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);

        vm.prank(BOB);
        staking.stakeFor(BOB, 1_000e18);

        skip(5 minutes);

        vm.prank(ALICE);
        staking.stakeFor(ALICE, 1_000e18);

        //5_250 00 00 00 00 00 00 00 00 00
        //1_750 00 00 00 00 00 00 00 00 00

        skip(5 minutes);

        (, uint128 pendingRewardsAlice2) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingRewardsBob2) = staking.calculatePendingRewards(address(BOB));

        console.log("Second Pending rewards Alice: ", pendingRewardsAlice2);
        console.log("Second Pending rewards Bob: ", pendingRewardsBob2);

        /**
         *   First Pending rewards Alice:  3_500 00 00 00 00 00 00 00 00 00
         *   First Pending rewards Bob:  0
         *   Second Pending rewards Alice:  6_413 75 00 00 00 00 00 00 00 00
         *   Second Pending rewards Bob:   551 25 00 00 00 00 00 00 00 00
         */
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_StakeTokens(address userA, address userB, uint256 amount) public startEndPresale {
        amount = bound(amount, 2e18, 100_000e18);

        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(amount / 2));

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stakeFor(userA, uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), amount / 2);
        staking.stakeFor(userB, uint128(amount / 2));
        vm.stopPrank();

        //assertions
        assertEq(staking.totalStaked(), amount + (amount / 2));
        assertEq(staking.getUserStake(userA).stakeAmount, amount);
        assertEq(staking.getUserStake(userB).stakeAmount, amount / 2);
        assertEq(sToken.balanceOf(userA), amount);
        assertEq(sToken.balanceOf(userB), amount / 2);
        assertEq(sToken.totalSupply(), amount + (amount / 2));
        assertEq(sToken.totalSupply(), sToken.balanceOf(userA) + sToken.balanceOf(userB));
    }

    function testFuzz_UnStakeTokensWithNoRewardsAvailable(address userA, address userB, uint256 amount)
        public
        startEndPresale
    {
        amount = bound(amount, 2e18, 100_000e18);

        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(amount / 2));

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stakeFor(userA, uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), amount / 2);
        staking.stakeFor(userB, uint128(amount / 2));
        vm.stopPrank();

        skip(5 minutes);

        (uint128 pendingRewardsUserA,) = staking.calculatePendingRewards(userA);
        (uint128 pendingRewardsUserB,) = staking.calculatePendingRewards(userB);

        assertEq(pendingRewardsUserA, 0);
        assertEq(pendingRewardsUserB, 0);

        vm.startPrank(userA);
        staking.unStake(userA, uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        staking.unStake(userB, uint128(amount / 2));
        vm.stopPrank();

        //assertions
        assertEq(staking.totalStaked(), 0);
        assertEq(staking.getUserStake(userA).stakeAmount, 0);
        assertEq(staking.getUserStake(userB).stakeAmount, 0);
        assertEq(sToken.balanceOf(userA), 0);
        assertEq(sToken.balanceOf(userB), 0);
        assertEq(sToken.totalSupply(), 0);
    }

    function testFuzz_UnStakeTokensWithUSDCRewardsAvailable(address userA, address userB, uint256 amount)
        public
        startEndPresale
    {
        amount = bound(amount, 2e18, 1_000_000e18);

        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);

        uint256 userBAmount = amount.mulDiv(1, 2, Math.Rounding.Ceil);

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(userBAmount));

        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stakeFor(userA, uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), userBAmount);

        staking.stakeFor(userB, uint128(userBAmount));
        vm.stopPrank();

        skip(5 minutes);
        (uint128 pendingRewardsUserA,) = staking.calculatePendingRewards(userA);

        skip(5 minutes);
        (uint128 pendingRewardsUserB,) = staking.calculatePendingRewards(userB);

        //uint256 userAcalculatedPendingRewards = (amount * 6_000e6) / (amount + (amount / 2));
        uint256 userAcalculatedPendingRewards = amount.mulDiv(6_000e6, staking.totalStaked());
        //uint256 userBcalculatedPendingRewards = ((amount / 2) * 6_000e6) / (amount + (amount / 2));
        uint256 userBcalculatedPendingRewards = (userBAmount).mulDiv(6_000e6, staking.totalStaked());

        console.log("UserA amount", amount);
        console.log("UserB amount", userBAmount);
        console.log("totalStaked-cal", amount + userBAmount);
        console.log("Total Staked", staking.totalStaked());

        console.log("UserA calculated pending rewards", userAcalculatedPendingRewards);
        console.log("UserB calculated pending rewards", userBcalculatedPendingRewards);

        console.log("Pending rewards UserA: ", pendingRewardsUserA);
        console.log("Pending rewards UserB: ", pendingRewardsUserB);
        console.log("Total Pending rewards: ", pendingRewardsUserA + pendingRewardsUserB);
        uint256 totalPendingRewards = pendingRewardsUserA + pendingRewardsUserB;

        console.log("Diff", 6_000e6 - totalPendingRewards);

        vm.prank(userA);
        staking.unStake(userA, uint128(amount));

        vm.prank(userB);
        staking.unStake(userB, uint128(userBAmount));

        // assertEq(pendingRewardsUserA, userAcalculatedPendingRewards);
    }

    function testFuzz_UnStakeTokensWithSafeRewardsAvailable(address userA, address userB, uint256 amount) public { }
}
