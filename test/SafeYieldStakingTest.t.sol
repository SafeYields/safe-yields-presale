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

    function testStakeForShouldFailIfStakeAmountIsLessThanMin() public {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_INVALID_STAKE_AMOUNT.selector);
        vm.startPrank(ALICE);
        staking.stakeFor(ALICE, 9e17);
        vm.stopPrank();
    }

    function testUnStakeForShouldFailIfUnStakeAmountIsLessThanMin() public {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_INVALID_STAKE_AMOUNT.selector);
        vm.startPrank(ALICE);
        staking.unStake(ALICE, 9e17);
        vm.stopPrank();
    }

    function testUnStakeShouldFailIfUserHasNoStake() public {
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_INSUFFICIENT_STAKE.selector);
        vm.startPrank(ALICE);
        staking.unStake(ALICE, 1_000e18);
        vm.stopPrank();
    }

    function testStakeShouldRevertIfPreSaleIsLiveAndCallerIsNotAdmin() public {
        vm.prank(protocolAdmin);
        presale.startPresale();
        vm.expectRevert(SafeYieldStaking.SAFE_YIELD_STAKING_LOCKED.selector);
        vm.prank(NOT_ADMIN);
        staking.stakeFor(NOT_ADMIN, 1_000e18);
    }

    function testClaimUsdcRewards() public {
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
        uint128 pendingUsdcRewardsAlice = staking.calculatePendingRewards(address(ALICE));
        uint128 pendingUsdcRewardsBob = staking.calculatePendingRewards(address(BOB));

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

        //assertions
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalanceBefore + pendingUsdcRewardsAlice);
        assertEq(bobUsdcBalanceAfter, bobUsdcBalanceBefore + pendingUsdcRewardsBob);
        assertEq(staking.calculatePendingRewards(address(ALICE)), 0);
        assertEq(staking.calculatePendingRewards(address(BOB)), 0);
    }

    function testClaimSafeRewards() public {
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
        uint128 pendingUsdcRewardsAlice = staking.calculatePendingRewards(address(ALICE));
        uint128 pendingUsdcRewardsBob = staking.calculatePendingRewards(address(BOB));

        console.log("Pending rewards Alice: ", pendingUsdcRewardsAlice);
        console.log("Pending rewards Bob: ", pendingUsdcRewardsBob);

        uint256 aliceUsdcBalanceBefore = safeToken.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.claimRewards();
        uint256 aliceUsdcBalanceAfter = safeToken.balanceOf(address(ALICE));

        uint256 bobUsdcBalanceBefore = safeToken.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.claimRewards();
        uint256 bobUsdcBalanceAfter = safeToken.balanceOf(address(BOB));

        //assertions
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalanceBefore + pendingUsdcRewardsAlice);
        assertEq(bobUsdcBalanceAfter, bobUsdcBalanceBefore + pendingUsdcRewardsBob);
        assertEq(staking.calculatePendingRewards(address(ALICE)), 0);
        assertEq(staking.calculatePendingRewards(address(BOB)), 0);
    }

    function testStakeSafeTokens() public {
        vm.startPrank(address(distributor));
        safeToken.approve(address(staking), 10_000e18);

        staking.stakeFor(address(distributor), 1_000e18);

        assertEq(staking.totalStaked(), 1_000e18);
        assertEq(staking.getUserStake(address(distributor)).stakeAmount, 1_000e18);
    }

    function testUnStakeSafeTokensAndClaimUsdcRewards() public {
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

        uint128 pendingUsdcRewardsAlice = staking.calculatePendingRewards(address(ALICE));
        uint128 pendingUsdcRewardsBob = staking.calculatePendingRewards(address(BOB));

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

    function testStakeSafeTokensGetUsdcRewards() public {
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

        uint128 pendingRewardsAlice = staking.calculatePendingRewards(address(ALICE));
        uint128 pendingRewardsBob = staking.calculatePendingRewards(address(BOB));

        console.log("First Pending rewards Alice: ", pendingRewardsAlice);
        console.log("First Pending rewards Bob: ", pendingRewardsBob);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);

        vm.prank(ALICE);
        staking.stakeFor(ALICE, 1_000e18);

        skip(5 minutes);

        vm.prank(BOB);
        staking.stakeFor(BOB, 1_000e18);

        skip(5 minutes);

        uint128 pendingRewardsAlice2 = staking.calculatePendingRewards(address(ALICE));
        uint128 pendingRewardsBob2 = staking.calculatePendingRewards(address(BOB));

        console.log("Second Pending rewards Alice: ", pendingRewardsAlice2);
        console.log("Second Pending rewards Bob: ", pendingRewardsBob2);
    }

    function testStakeSafeTokensGetSafeRewards() public {
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

        uint128 pendingRewardsAlice = staking.calculatePendingRewards(address(ALICE));

        uint128 pendingRewardsBob = staking.calculatePendingRewards(address(BOB));

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

        uint128 pendingRewardsAlice2 = staking.calculatePendingRewards(address(ALICE));

        uint128 pendingRewardsBob2 = staking.calculatePendingRewards(address(BOB));

        console.log("Second Pending rewards Alice: ", pendingRewardsAlice2);
        console.log("Second Pending rewards Bob: ", pendingRewardsBob2);

        /**
         *   First Pending rewards Alice:  3_500 00 00 00 00 00 00 00 00 00
         *   First Pending rewards Bob:  0
         *   Second Pending rewards Alice:  6_413 75 00 00 00 00 00 00 00 00
         *   Second Pending rewards Bob:   551 25 00 00 00 00 00 00 00 00
         */
    }

    function _transferSafeTokens(address user, uint128 amount) internal {
        vm.prank(address(distributor));
        safeToken.transfer(user, amount);
    }
}
