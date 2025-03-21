// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";
import { SafeYieldStaking, Stake } from "src/SafeYieldStaking.sol";
import { VestingSchedule } from "src/types/SafeTypes.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function testIfUsdcTokensAreSetCorrectly() public view {
        assertEq(address(usdc), address(staking.usdc()));
    }

    function testStakeShouldFailIfDuringPresale() public {
        vm.prank(ALICE);
        vm.expectRevert(SafeYieldStaking.SYST__STAKING_LOCKED.selector);
        staking.stake(100e6);
    }

    function testShouldFailIfApproveAgentIsInvalid() public {
        vm.prank(protocolAdmin);
        vm.expectRevert(SafeYieldStaking.SYST__INVALID_ADDRESS.selector);

        staking.approveStakingAgent(address(0), true);
    }

    function testIfApproveAgentIsSetCorrectly() public {
        vm.prank(protocolAdmin);

        staking.approveStakingAgent(makeAddr("New Agent"), true);

        assertEq(staking.approvedStakingAgent(makeAddr("New Agent")), true);
    }

    function testSetNewConfig() public {
        vm.startPrank(protocolAdmin);

        staking.setConfig(makeAddr("NewConfig"));

        assertEq(address(staking.safeYieldConfigs()), makeAddr("NewConfig"));
    }

    function testShouldFailAddCallbackIfAddressIsZero() public {
        vm.startPrank(protocolAdmin);

        vm.expectRevert(SafeYieldStaking.SYST__INVALID_ADDRESS.selector);
        staking.addCallback(address(0));
    }

    function testShouldFailIfIndexIsGreaterThanCallbackLength() public {
        vm.expectRevert(SafeYieldStaking.SYST__NO_CALLBACK_INDEX.selector);
        staking.getCallback(3);
    }

    function testShouldFailIfCallbackAlreadyAdded() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldStaking.SYST__CALLBACK_ALREADY_REGISTERED.selector);
        staking.addCallback(address(tokensDistributor));
    }

    function testShouldFailIfCallbackNotFound() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldStaking.SYST__CALLBACK_NOT_FOUND.selector);
        staking.removeCallback(makeAddr("Unknown"));
    }

    function testAddCallBackIsAddedCorrectly() public {
        vm.startPrank(protocolAdmin);

        staking.addCallback(makeAddr("New Callback"));

        assertEq(staking.getAllCallbacks().length, 2);
        assertEq(staking.getCallback(1), makeAddr("New Callback"));
    }

    function testRemoveCallBackIsRemovedCorrectly() public {
        vm.startPrank(protocolAdmin);

        staking.addCallback(makeAddr("New Callback"));

        staking.removeCallback(makeAddr("New Callback"));

        assertEq(staking.getAllCallbacks().length, 1);
    }

    function testStakeForShouldFailIfPresaleIsLiveAndCallerIsNotPresale() public startPresale {
        vm.expectRevert(SafeYieldStaking.SYST__STAKING_LOCKED.selector);
        vm.prank(ALICE);
        staking.stake(1_000e18);
    }

    function testStakeForShouldFailIfPresaleEndedBut_IDO_IsNotLive() public startEndPresale {
        vm.expectRevert(SafeYieldStaking.SYST__STAKING_LOCKED.selector);
        vm.prank(ALICE);
        staking.stake(1_000e18);
    }

    function testStakeForShouldFailIfStakeAmountIsLessThanMin() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        vm.expectRevert(SafeYieldStaking.SYST__INVALID_STAKE_AMOUNT.selector);
        vm.startPrank(ALICE);
        staking.stake(0);
        vm.stopPrank();
    }

    function testUnStakeForShouldFailIfUnStakeAmountIsLessThanMin() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        vm.expectRevert(SafeYieldStaking.SYST__INVALID_STAKE_AMOUNT.selector);
        vm.startPrank(ALICE);
        staking.unStake(0);
        vm.stopPrank();
    }

    function testUnStakeShouldFailIfUserHasNoStake() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        vm.expectRevert(SafeYieldStaking.SYST__INSUFFICIENT_STAKE.selector);
        vm.startPrank(ALICE);
        staking.unStake(1_000e18);
        vm.stopPrank();
    }

    function testClaimUsdcRewards() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();
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
        staking.stake(2_000e18);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        skip(5 minutes);
        (uint128 pendingUsdcRewardsAlice,,,) = staking.calculatePendingRewards(address(ALICE));

        (uint128 pendingUsdcRewardsBob,,,) = staking.calculatePendingRewards(address(BOB));

        uint256 aliceUsdcBalanceBefore = usdc.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.claimRewards(ALICE);
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(address(ALICE));

        uint256 bobUsdcBalanceBefore = usdc.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.claimRewards(BOB);
        uint256 bobUsdcBalanceAfter = usdc.balanceOf(address(BOB));

        (uint128 pendingUsdcRewardsAliceAfter,,,) = staking.calculatePendingRewards(address(ALICE));
        (uint128 pendingUsdcRewardsBobAfter,,,) = staking.calculatePendingRewards(address(BOB));

        //assertions
        assertEq(aliceUsdcBalanceAfter, aliceUsdcBalanceBefore + pendingUsdcRewardsAlice);
        assertEq(bobUsdcBalanceAfter, bobUsdcBalanceBefore + pendingUsdcRewardsBob);
        assertEq(pendingUsdcRewardsAliceAfter, 0);
        assertEq(pendingUsdcRewardsBobAfter, 0);
    }

    function testClaimSafeRewards() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();
        vm.stopPrank();

        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(2_000e18);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
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
        (, uint128 pendingRewardsAlice,,) = staking.calculatePendingRewards(address(ALICE));

        skip(5 minutes);
        (, uint128 pendingRewardsBob,,) = staking.calculatePendingRewards(address(BOB));

        console.log("Pending Safe Rewards for Alice", pendingRewardsAlice);
        //
        console.log("Pending Usdc Rewards for Bob", pendingRewardsBob);

        usdc.mint(address(distributor), 10_000e6);

        skip(1 hours);

        console.log("Second Rewards*********************");
        console.log("ALice Pending*********");
        (, uint128 pendingRewardsAlice2,,) = staking.calculatePendingRewards(address(ALICE));

        console.log("BOB Pending*********");
        skip(5 minutes);
        (, uint128 pendingRewardsBob2,,) = staking.calculatePendingRewards(address(BOB));

        skip(5 minutes);

        uint256 aliceSafeBalanceBefore = safeToken.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.claimRewards(ALICE);
        uint256 aliceSafeBalanceAfter = safeToken.balanceOf(address(ALICE));

        uint256 bobSafeBalanceBefore = safeToken.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.claimRewards(BOB);
        uint256 bobSafeBalanceAfter = safeToken.balanceOf(address(BOB));

        /**
         * Accumulated Rewards become 7_000e18 safe tokens
         * to calculate user share = amountStaked *  accumulated / totalStaked
         */
        uint256 aliceCalculatedRewards = (2_000e18 * 7_000e18);
        uint256 bobCalculatedRewards = (1_000e18 * 7_000e18);

        assertApproxEqAbs(pendingRewardsAlice2, (aliceCalculatedRewards) / 3_000e18, 1e4);
        assertApproxEqAbs(pendingRewardsBob2, (bobCalculatedRewards) / 3_000e18, 1e4);
        assertEq(aliceSafeBalanceAfter, aliceSafeBalanceBefore + pendingRewardsAlice2);
        assertEq(bobSafeBalanceAfter, bobSafeBalanceBefore + pendingRewardsBob2);

        usdc.mint(address(distributor), 10_000e6);

        skip(1 hours);

        console.log("Third Rewards*********************");
        console.log("ALice Pending 3*********");
        (, uint128 pendingRewardsAlice3,,) = staking.calculatePendingRewards(address(ALICE));

        console.log("BOB Pending 3*********");
        skip(5 minutes);
        (, uint128 pendingRewardsBob3,,) = staking.calculatePendingRewards(address(BOB));

        skip(5 minutes);

        console.log("Pending Safe Rewards for Alice3", pendingRewardsAlice3);
        //
        console.log("Pending Usdc Rewards for Bob3", pendingRewardsBob3);

        uint256 aliceSafeBalanceBefore2 = safeToken.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.claimRewards(ALICE);
        uint256 aliceSafeBalanceAfter2 = safeToken.balanceOf(address(ALICE));

        uint256 bobSafeBalanceBefore2 = safeToken.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.claimRewards(BOB);
        uint256 bobSafeBalanceAfter2 = safeToken.balanceOf(address(BOB));

        assertNotEq(pendingRewardsAlice3, 0);
        assertNotEq(pendingRewardsBob3, 0);
        assertEq(aliceSafeBalanceAfter2, aliceSafeBalanceBefore2 + pendingRewardsAlice3);
        assertEq(bobSafeBalanceAfter2, bobSafeBalanceBefore2 + pendingRewardsBob3);
    }

    function testStakeSafeTokensForAndVest() public startEndPresale {
        _transferSafeTokens(protocolAdmin, 10_000e18);

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), 5_000e18);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        skip(30 * 24 * 60 * 60 seconds); //1 month

        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        skip(30 * 24 * 60 * 60 seconds); //1 month

        //alice claiming some safe tokens after presale has ended
        vm.startPrank(ALICE);
        staking.unstakeVestedTokens();
        vm.stopPrank();

        uint256 timestamp = block.timestamp - safeYieldVesting.ONE_MONTH();

        uint256 monthsElapsed = (timestamp * 10_000) / safeYieldVesting.ONE_MONTH();

        uint256 unlockedPercentage = (monthsElapsed * 2_000) / 10_000;

        uint256 aliceCalculatedSafe = (unlockedPercentage * 2_000e18) / 10_000;

        /**
         * after a month alice can claim 400 Safe tokens
         * as 20% of 2_000 each month is 400
         */
        assertEq(safeToken.balanceOf(ALICE), 400e18);
        //2000 00 00 00 00 00 00 00 00 00
    }

    function testStakeSafeTokensForNoVest() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        _transferSafeTokens(protocolAdmin, 10_000e18);

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), 5_000e18);
        staking.stakeFor(ALICE, 2_000e18, false);
        vm.stopPrank();

        skip(1 days);
        vm.prank(ALICE);
        staking.unStake(1_000e18);

        assertEq(safeToken.balanceOf(ALICE), 1_000e18);
    }

    function testStakeAndVestForBeforeIDOStarts() public startEndPresale {
        _transferSafeTokens(protocolAdmin, 10_000e18);

        skip(5 days);

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), 5_000e18);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        Stake memory aliceStake = staking.getUserStake(ALICE);
        assertEq(aliceStake.stakeAmount, 2_000e18);

        VestingSchedule memory aliceVestingSchedule1 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule1.start, 0);
        assertEq(aliceVestingSchedule1.totalAmount, 2_000e18);

        skip(30 * 24 * 60 * 60 seconds); //30 days

        //after admin sets start time when IDO has ended.
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        //432001
        //2592000
        /**
         * when user is claiming safe the user start time should be equal to vestStart time
         */
        skip(30 * 24 * 60 * 60 seconds); //30 days

        /**
         * 1 months = 20%
         * First month Alice 20% of 2_000e18 = 400 say tokens
         */

        //alice claiming some safe tokens after presale has ended
        vm.startPrank(ALICE);
        staking.unstakeVestedTokens();
        vm.stopPrank();

        uint256 timestamp = block.timestamp - aliceVestingSchedule1.cliff;

        uint256 monthsElapsed = (timestamp * 10_000) / safeYieldVesting.ONE_MONTH();

        uint256 unlockedPercentage = (monthsElapsed * 2_000) / 10_000;

        uint256 aliceCalculatedSafe = (unlockedPercentage * 2_000e18) / 10_000;

        VestingSchedule memory aliceVestingSchedule2 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule2.start, configs.vestStartTime());
        assertEq(aliceVestingSchedule2.amountClaimed, aliceCalculatedSafe);
        assertEq(safeToken.balanceOf(ALICE), aliceCalculatedSafe);
    }

    function testUnlocksSayAndUnstake() public startEndPresale {
        _transferSafeTokens(protocolAdmin, 10_000e18);

        skip(5 days);

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), 5_000e18);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        Stake memory aliceStake = staking.getUserStake(ALICE);
        assertEq(aliceStake.stakeAmount, 2_000e18);

        skip(1 weeks);

        VestingSchedule memory aliceVestingSchedule1 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule1.start, 0);
        assertEq(aliceVestingSchedule1.totalAmount, 2_000e18);

        skip(30 * 24 * 60 * 60 seconds); //30 days

        //after admin sets start time when IDO has ended.
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        skip(30 * 24 * 60 * 60 seconds); //30 days

        vm.prank(ALICE);
        safeYieldVesting.unlock_sSayTokens();

        VestingSchedule memory aliceVestingSchedule2 = safeYieldVesting.getSchedules(ALICE);

        uint256 timestamp = block.timestamp - aliceVestingSchedule1.cliff;

        uint256 monthsElapsed = (timestamp * 10_000) / safeYieldVesting.ONE_MONTH();

        uint256 unlockedPercentage = (monthsElapsed * 2_000) / 10_000;

        uint256 aliceCalculatedSafe = (unlockedPercentage * 2_000e18) / 10_000;

        assertEq(aliceVestingSchedule2.amountClaimed, aliceCalculatedSafe);
        assertEq(IERC20(address(staking)).balanceOf(ALICE), aliceCalculatedSafe);
        assertEq(safeToken.balanceOf(ALICE), 0);

        vm.prank(ALICE);
        staking.unStake(200e18);

        assertEq(safeToken.balanceOf(ALICE), 200e18);

        Stake memory aliceNewStake = staking.getUserStake(ALICE);
        assertEq(aliceNewStake.stakeAmount, 1_800e18);
    }

    function testStakeForOverrides() public startEndPresale {
        vm.warp(1729166198000);
        _transferSafeTokens(protocolAdmin, 10_000e18);

        skip(5 days);

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), 10_000e18);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        VestingSchedule memory aliceVestingSchedule1 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule1.start, 0);
        assertEq(aliceVestingSchedule1.totalAmount, 2_000e18);

        skip(5 days);

        vm.startPrank(protocolAdmin);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        VestingSchedule memory aliceVestingSchedule2 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule2.start, 0);
        assertEq(aliceVestingSchedule2.totalAmount, 4_000e18);

        skip(10 minutes);
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        skip(30 * 24 * 60 * 60 seconds);
        vm.startPrank(protocolAdmin);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        VestingSchedule memory aliceVestingSchedule3 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule3.start, block.timestamp);
        assertEq(aliceVestingSchedule3.totalAmount, 2_000e18);
    }

    function testStakeAndVestForWhenIDOEnds() public startEndPresale {
        _transferSafeTokens(protocolAdmin, 10_000e18);

        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), 5_000e18);
        staking.stakeFor(ALICE, 2_000e18, true);
        vm.stopPrank();

        VestingSchedule memory aliceVestingSchedule1 = safeYieldVesting.getSchedules(ALICE);
        assertEq(aliceVestingSchedule1.start, block.timestamp);
        assertEq(aliceVestingSchedule1.totalAmount, 2_000e18);
    }

    function testUnStakeSafeTokensAndClaimUsdcRewards() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(2_000e18);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        (uint128 pendingUsdcRewardsAlice,,,) = staking.calculatePendingRewards(address(ALICE));

        (uint128 pendingUsdcRewardsBob,,,) = staking.calculatePendingRewards(address(BOB));

        console.log("Pending rewards Alice: ", pendingUsdcRewardsAlice);
        console.log("Pending rewards Bob: ", pendingUsdcRewardsBob);

        uint256 aliceUsdcBalanceBefore = usdc.balanceOf(address(ALICE));
        vm.prank(ALICE);
        staking.unStake(1_000e18);
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(address(ALICE));

        uint256 bobUsdcBalanceBefore = usdc.balanceOf(address(BOB));
        vm.prank(BOB);
        staking.unStake(600e18);
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
        assertEq(staking.balanceOf(address(ALICE)), 1_000e18);
        assertEq(staking.getUserStake(address(BOB)).stakeAmount, 400e18);
        assertEq(staking.balanceOf(address(BOB)), 400e18);
    }

    function testStakeSafeTokensGetUsdcRewards() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        skip(5 minutes);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(2_000e18);
        vm.stopPrank();

        skip(5 minutes);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        console.log("First Rewards***************************");
        skip(5 minutes);

        (uint128 pendingUsdcRewardsAlice,,,) = staking.calculatePendingRewards(address(ALICE));
        /**
         * distributed in USDC.
         * 60% goes to safe stakers
         */
        uint256 stakingAccumulatedUsdcPerStakePrior = (6_000e6 * 1e18) / 3_000e18;

        uint256 aliceUsdcRewardsPerStake = (1_000e18 * stakingAccumulatedUsdcPerStakePrior) / 1e18;
        assertEq(aliceUsdcRewardsPerStake, pendingUsdcRewardsAlice, "alice rewards per stake is invalid");

        skip(5 minutes);
        (uint128 pendingUsdcRewardsBOB,,,) = staking.calculatePendingRewards(address(BOB));

        uint256 bobUsdcRewardsPerStake = (2_000e18 * stakingAccumulatedUsdcPerStakePrior) / 1e18;
        assertEq(bobUsdcRewardsPerStake, pendingUsdcRewardsBOB, "bob rewards per stake is invalid");

        skip(5 minutes);
        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        console.log("Second Rewards***************************");

        uint256 stakingAccumulatedUsdcPerStakeAfter = stakingAccumulatedUsdcPerStakePrior + (6_000e6 * 1e18) / 3_000e18;

        skip(5 minutes);
        (uint128 pendingUsdcRewardsAlice2,,,) = staking.calculatePendingRewards(address(ALICE));

        uint256 aliceUsdcRewardsPerStakeSecondRewards = (1_000e18 * stakingAccumulatedUsdcPerStakeAfter) / 1e18;

        assertEq(aliceUsdcRewardsPerStakeSecondRewards, pendingUsdcRewardsAlice2);

        skip(5 minutes);
        (uint128 pendingUsdcRewardsBOB2,,,) = staking.calculatePendingRewards(address(BOB));

        uint256 bobUsdcRewardsPerStakeSecondRewards = (2_000e18 * stakingAccumulatedUsdcPerStakeAfter) / 1e18;

        assertEq(bobUsdcRewardsPerStakeSecondRewards, pendingUsdcRewardsBOB2);
    }

    function testStakeSafeTokensGetSafeRewards() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();

        distributor.switchSharesPerPhase();
        vm.stopPrank();

        _transferSafeTokens(ALICE, 10_000e18);

        _transferSafeTokens(BOB, 10_000e18);

        skip(5 minutes);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(2_000e18);
        vm.stopPrank();

        skip(5 minutes);

        /**
         * 35% of the rewards will be distributed to $SAFE stakers.
         */
        (, uint128 pendingRewardsAlice,,) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingRewardsBob,,) = staking.calculatePendingRewards(address(BOB));

        assertEq(pendingRewardsAlice, 0);
        assertEq(pendingRewardsBob, 0);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);

        (, uint128 pendingRewardsAlice2,,) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingRewardsBob2,,) = staking.calculatePendingRewards(address(BOB));

        uint256 totalStaked = 3_000e18;
        uint256 aliceCalculatedPendingRewards = (1_000e18 * 3_500e18) / totalStaked;
        uint256 bobCalculatedPendingRewards = (2_000e18 * 3_500e18) / totalStaked;

        assertApproxEqAbs(aliceCalculatedPendingRewards, pendingRewardsAlice2, 1e4);
        assertApproxEqAbs(bobCalculatedPendingRewards, pendingRewardsBob2, 1e4);

        skip(5 minutes);

        vm.prank(BOB);
        staking.stake(1_000e18);

        skip(5 minutes);

        vm.prank(ALICE);
        staking.stake(1_000e18);

        skip(5 minutes);

        (, uint128 pendingRewardsAlice3,,) = staking.calculatePendingRewards(address(ALICE));

        (, uint128 pendingRewardsBob3,,) = staking.calculatePendingRewards(address(BOB));

        assertEq(pendingRewardsAlice2, pendingRewardsAlice3);
        assertEq(pendingRewardsBob2, pendingRewardsBob3);
    }

    function testStakePOC_RewardsDebtCalculations() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        skip(5 minutes);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);

        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        Stake memory aliceStake = staking.getUserStake(ALICE);

        console.log("alice reward debt", uint256(int256(aliceStake.usdcRewardsDebt)));

        skip(5 minutes);

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        Stake memory bobStake = staking.getUserStake(BOB);

        console.log("bob reward debt", uint256(int256(bobStake.usdcRewardsDebt)));

        skip(10 days);

        vm.prank(protocolAdmin);
        usdc.mint(address(distributor), 10_000e6);

        (uint128 pendingUsdcRewardsAlice,,,) = staking.calculatePendingRewards(address(ALICE));
        (uint128 pendingUsdcRewardsBob,,,) = staking.calculatePendingRewards(address(BOB));

        console.log("Alice pending usdc rewards", pendingUsdcRewardsAlice);
        console.log("Bob pending usdc rewards", pendingUsdcRewardsBob);
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_StakeFor(uint256 amount) public startEndPresale {
        amount = bound(amount, 2e18, 10_000e18);

        _transferSafeTokens(protocolAdmin, 10_000e18);

        vm.startPrank(protocolAdmin);
        safeToken.approve(address(staking), amount);
        staking.stakeFor(ALICE, uint128(amount), true);
        vm.stopPrank();

        skip(30 * 24 * 60 * 60 seconds); //1 month

        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        skip(30 * 24 * 60 * 60 seconds); //1 month

        //alice claiming some safe tokens after presale has ended
        vm.startPrank(ALICE);
        staking.unstakeVestedTokens();
        vm.stopPrank();

        uint256 timestamp = block.timestamp - safeYieldVesting.ONE_MONTH();

        uint256 monthsElapsed = (timestamp * 10_000) / safeYieldVesting.ONE_MONTH();

        uint256 unlockedPercentage = (monthsElapsed * 2_000) / 10_000;

        uint256 aliceCalculatedSafe = (unlockedPercentage * amount) / 10_000;

        /**
         * after a month alice can claim 400 Safe tokens
         * as 20% of 2_000 each month is 400
         */
        assertEq(safeToken.balanceOf(ALICE), aliceCalculatedSafe);
    }

    function testFuzz_StakeTokens(address userA, address userB, uint256 amount) public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        amount = bound(amount, 2e18, 100_000e18);
        userA = makeAddr("userA");
        userB = makeAddr("userB");

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(amount / 2));

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stake(uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), amount / 2);
        staking.stake(uint128(amount / 2));
        vm.stopPrank();

        //assertions
        assertEq(staking.totalStaked(), amount + (amount / 2));
        assertEq(staking.getUserStake(userA).stakeAmount, amount);
        assertEq(staking.getUserStake(userB).stakeAmount, amount / 2);
        assertEq(staking.balanceOf(userA), amount);
        assertEq(staking.balanceOf(userB), amount / 2);
        assertEq(staking.totalSupply(), amount + (amount / 2));
        assertEq(staking.totalSupply(), staking.balanceOf(userA) + staking.balanceOf(userB));
    }

    function testFuzz_UnStakeTokensWithNoRewardsAvailable(address userA, address userB, uint256 amount)
        public
        startEndPresale
    {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        amount = bound(amount, 2e18, 100_000e18);

        userA = makeAddr("userA");
        userB = makeAddr("userB");

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(amount / 2));

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stake(uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), amount / 2);
        staking.stake(uint128(amount / 2));
        vm.stopPrank();

        skip(5 minutes);

        (uint128 pendingRewardsUserA,,,) = staking.calculatePendingRewards(userA);
        (uint128 pendingRewardsUserB,,,) = staking.calculatePendingRewards(userB);

        assertEq(pendingRewardsUserA, 0);
        assertEq(pendingRewardsUserB, 0);

        vm.startPrank(userA);
        staking.unStake(uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        staking.unStake(uint128(amount / 2));
        vm.stopPrank();

        //assertions
        assertEq(staking.totalStaked(), 0);
        assertEq(staking.getUserStake(userA).stakeAmount, 0);
        assertEq(staking.getUserStake(userB).stakeAmount, 0);
        assertEq(staking.balanceOf(userA), 0);
        assertEq(staking.balanceOf(userB), 0);
        assertEq(staking.totalSupply(), 0);
    }

    function testFuzz_UnStakeTokensWithUSDCRewardsAvailable(address userA, address userB, uint256 amount)
        public
        startEndPresale
    {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        amount = bound(amount, 2e18, 1_000_000e18);
        userA = makeAddr("userA");
        userB = makeAddr("userB");

        uint256 userBAmount = amount.mulDiv(1, 2, Math.Rounding.Ceil);

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(userBAmount));

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stake(uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), userBAmount);
        staking.stake(uint128(userBAmount));
        vm.stopPrank();

        uint256 userASafeBalancePrior = safeToken.balanceOf(userA);
        uint256 userBSafeBalancePrior = safeToken.balanceOf(userB);

        skip(10 minutes);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);
        (uint128 pendingRewardsUserA,,,) = staking.calculatePendingRewards(userA);

        skip(5 minutes);
        (uint128 pendingRewardsUserB,,,) = staking.calculatePendingRewards(userB);

        uint256 userAcalculatedPendingRewards = amount.mulDiv(6_000e6, staking.totalStaked(), Math.Rounding.Floor);
        uint256 userBcalculatedPendingRewards =
            (userBAmount).mulDiv(6_000e6, staking.totalStaked(), Math.Rounding.Floor);

        assertApproxEqAbs(pendingRewardsUserA, userAcalculatedPendingRewards, 1e6, "user A pending rewards invalid");
        assertApproxEqAbs(pendingRewardsUserB, userBcalculatedPendingRewards, 1e6, "user B pending rewards invalid");

        uint256 userAUsdcBalancePrior = usdc.balanceOf(userA);
        uint256 userBUsdcBalancePrior = usdc.balanceOf(userB);

        vm.prank(userA);
        staking.unStake(uint128(amount));

        vm.prank(userB);
        staking.unStake(uint128(userBAmount));

        assertEq(safeToken.balanceOf(userA), userASafeBalancePrior + amount);
        assertEq(safeToken.balanceOf(userB), userBSafeBalancePrior + userBAmount);
        assertApproxEqAbs(
            usdc.balanceOf(userA),
            userAcalculatedPendingRewards + userAUsdcBalancePrior,
            1e6,
            "user A pending rewards invalid"
        );
        assertApproxEqAbs(
            usdc.balanceOf(userB),
            userBcalculatedPendingRewards + userBUsdcBalancePrior,
            1e6,
            "user B pending rewards invalid"
        );
    }

    function testFuzz_UnStakeTokensWithSafeRewardsAvailable(address userA, address userB, uint256 amount)
        public
        startEndPresale
    {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();

        distributor.switchSharesPerPhase();
        vm.stopPrank();

        amount = bound(amount, 2e18, 1_000_000e18);
        userA = makeAddr("userA");
        userB = makeAddr("userB");

        uint256 userBAmount = amount.mulDiv(1, 2, Math.Rounding.Ceil);

        _transferSafeTokens(userA, uint128(amount));
        _transferSafeTokens(userB, uint128(userBAmount));

        vm.startPrank(userA);
        safeToken.approve(address(staking), amount);
        staking.stake(uint128(amount));
        vm.stopPrank();

        vm.startPrank(userB);
        safeToken.approve(address(staking), userBAmount);
        staking.stake(uint128(userBAmount));
        vm.stopPrank();

        // uint256 userASafeBalancePrior = safeToken.balanceOf(userA);
        // uint256 userBSafeBalancePrior = safeToken.balanceOf(userB);

        skip(10 minutes);
        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);
        (, uint128 pendingSafeRewardsUserA,,) = staking.calculatePendingRewards(userA);

        skip(5 minutes);
        (, uint128 pendingSafeRewardsUserB,,) = staking.calculatePendingRewards(userB);

        uint256 aliceCalculatedSafeRewards = (amount * 3_500e18) / (amount + userBAmount);
        uint256 bobCalculatedSafeRewards = (userBAmount * 3_500e18) / (amount + userBAmount);

        assertApproxEqAbs(pendingSafeRewardsUserA, aliceCalculatedSafeRewards, 1e6, "alice pending rewards invalid");
        assertApproxEqAbs(pendingSafeRewardsUserB, bobCalculatedSafeRewards, 1e6, "bob pending rewards invalid");
    }
}
