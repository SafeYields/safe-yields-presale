// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";
import { SafeYieldStaking, Stake } from "src/SafeYieldStaking.sol";
import { RewardToken } from "src/types/SafeTypes.sol";
import { SafeYieldTokenDistributor, ISafeYieldTokensDistributor } from "src/SafeYieldTokenDistributor.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SafeYieldTokenDistributorTest is SafeYieldBaseTest {
    /*//////////////////////////////////////////////////////////////
                              NORMAL TESTS
    //////////////////////////////////////////////////////////////*/
    function testDepositRewardAsset() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        address[] memory rewardAssets = new address[](1);
        rewardAssets[0] = address(rewardToken);

        uint128[] memory amounts = new uint128[](1);
        amounts[0] = 500e18;

        skip(5 minutes);

        _transferSafeTokens(ALICE, 10_000e18);

        skip(5 minutes);

        //alice stakes
        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(2_000e18);
        vm.stopPrank();

        skip(5 minutes);

        vm.startPrank(protocolAdmin);
        rewardToken.approve(address(tokensDistributor), amounts[0]);
        tokensDistributor.depositReward(rewardAssets, amounts);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(tokensDistributor)), amounts[0]);

        address[] memory allRewardTokens = tokensDistributor.getAllRewardTokens();

        assertEq(allRewardTokens.length, 1);
        assertEq(allRewardTokens[0], address(rewardToken));
    }

    // /**
    //  * Test rewards before a user has staked pls.
    //  * Test rewards after a user has un-staked pls.
    //  * Test reward debt is tracked correctly for both cases as well as for new yield tokens.
    //  */
    function testRewardsAccruedDuringStaking__SingleYieldAsset() public {
        //first reward Deposits distribution
        testDepositRewardAsset();

        RewardToken memory rewardTokenFirstDeposit = tokensDistributor.getRewardTokens(address(rewardToken));

        uint256 firstAccumRewardsPerShare = (500e18 * 1e18) / staking.totalSupply();

        assertEq(
            firstAccumRewardsPerShare,
            rewardTokenFirstDeposit.accRewardPerShare,
            "AccumulatedRewardsPerShare is equal to calculated"
        );

        _transferSafeTokens(BOB, 10_000e18);

        //Bob Stakes
        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        /**
         * Bob rewardDebt (deposit * accumulatedRewardsPerShare)/1e18
         */
        uint256 bobRewardDebt = uint256(tokensDistributor.getUserRewardDebt(BOB, address(rewardToken)));
        uint256 bobCalculatedRewardDebt = (1_000e18 * rewardTokenFirstDeposit.accRewardPerShare) / 1e18;
        assertEq(bobRewardDebt, bobCalculatedRewardDebt, "Bob Reward Debt is not equal to expected rewards Debt");

        /**
         * Alice rewardDebt (deposit * accumulatedRewardsPerShare)/1e18
         */
        uint256 aliceRewardDebt = uint256(tokensDistributor.getUserRewardDebt(ALICE, address(rewardToken)));
        assertEq(aliceRewardDebt, 0, "Alice Reward Debt should be zero");

        /**
         * Alice should receive  rewards as her stake was before reward Distribution.
         */
        skip(2 weeks);

        uint256 aliceRewards = tokensDistributor.pendingRewards(ALICE, address(rewardToken));
        uint256 aliceCalculatedAccumulatedRewardsPerStake =
            (rewardTokenFirstDeposit.accRewardPerShare * tokensDistributor.getLastStakeBalance(ALICE)) / 1e18;
        uint256 aliceCalculatedRewards = aliceCalculatedAccumulatedRewardsPerStake - aliceRewardDebt;
        assertEq(aliceRewards, aliceCalculatedRewards, "Alice should receive rewards");

        /**
         * Bob should receive no rewards as her stake was after reward Distribution.
         */
        skip(2 weeks);

        uint256 bobRewards = tokensDistributor.pendingRewards(BOB, address(rewardToken));
        uint256 bobCalculatedAccumulatedRewardsPerStake =
            (rewardTokenFirstDeposit.accRewardPerShare * tokensDistributor.getLastStakeBalance(BOB)) / 1e18;
        uint256 bobCalculatedRewards = bobCalculatedAccumulatedRewardsPerStake - bobRewardDebt;
        assertEq(bobRewards, bobCalculatedRewards, "Bob should receive no rewards");
    }

    function testRewardsAccruedAfterUnStaking__SingleYieldAsset() public {
        //first reward Deposits distribution
        testDepositRewardAsset();

        RewardToken memory rewardTokenFirstDeposit = tokensDistributor.getRewardTokens(address(rewardToken));

        skip(5 minutes);

        int256 aliceRewardDebt = (tokensDistributor.getUserRewardDebt(ALICE, address(rewardToken)));

        uint256 aliceRewards = tokensDistributor.pendingRewards(ALICE, address(rewardToken));
        uint256 aliceCalculatedAccumulatedRewardsPerStake =
            (rewardTokenFirstDeposit.accRewardPerShare * tokensDistributor.getLastStakeBalance(ALICE)) / 1e18;
        uint256 aliceCalculatedRewards = aliceCalculatedAccumulatedRewardsPerStake - uint256(-aliceRewardDebt);
        assertEq(aliceRewards, aliceCalculatedRewards, "Alice should receive rewards");

        //alice un-Stakes
        vm.startPrank(ALICE);
        staking.unStake(500e18);

        skip(5 minutes);

        //alice claims
        vm.startPrank(ALICE);
        tokensDistributor.claimRewards(address(rewardToken));
    }

    function testRewardsAccrued__MultipleOps() public startEndPresale {
        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));
        vm.stopPrank();

        skip(5 minutes);

        _transferSafeTokens(ALICE, 10_000e18);
        _transferSafeTokens(BOB, 10_000e18);

        skip(5 minutes);

        //alice stakes
        vm.startPrank(ALICE);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        skip(5 minutes);

        address[] memory rewardAssets = new address[](1);
        rewardAssets[0] = address(rewardToken);

        uint128[] memory amounts = new uint128[](1);
        amounts[0] = 1_000e18;

        vm.startPrank(protocolAdmin);
        rewardToken.approve(address(tokensDistributor), amounts[0]);
        tokensDistributor.depositReward(rewardAssets, amounts);
        vm.stopPrank();

        vm.startPrank(BOB);
        safeToken.approve(address(staking), 10_000e18);
        staking.stake(1_000e18);
        vm.stopPrank();

        RewardToken memory rewardTokenFirstDeposit = tokensDistributor.getRewardTokens(address(rewardToken));

        uint256 aliceRewards = tokensDistributor.pendingRewards(ALICE, address(rewardToken));
        uint256 aliceCalculatedAccumulatedRewardsPerStake =
            (rewardTokenFirstDeposit.accRewardPerShare * tokensDistributor.getLastStakeBalance(ALICE)) / 1e18;
        uint256 aliceCalculatedRewards = aliceCalculatedAccumulatedRewardsPerStake - 0;
        assertEq(aliceRewards, aliceCalculatedRewards, "Alice should receive rewards");

        uint256 bobRewards = tokensDistributor.pendingRewards(BOB, address(rewardToken));
        assertEq(bobRewards, 0, "bob should receive no rewards");

        console.log("Alice Rewards", aliceRewards);
        console.log("Bob Rewards", bobRewards);

        skip(5 minutes);

        vm.prank(ALICE);
        tokensDistributor.claimRewards(address(rewardToken));

        skip(5 minutes);

        vm.prank(BOB);
        tokensDistributor.claimRewards(address(rewardToken));

        skip(5 minutes);

        uint128[] memory secondAmounts = new uint128[](1);
        secondAmounts[0] = 1_000e18;

        vm.startPrank(protocolAdmin);
        rewardToken.approve(address(tokensDistributor), secondAmounts[0]);
        tokensDistributor.depositReward(rewardAssets, secondAmounts);
        vm.stopPrank();

        //alice unStakes
        vm.prank(ALICE);
        staking.unStake(500e18);

        uint256 aliceSecondRewards = tokensDistributor.pendingRewards(ALICE, address(rewardToken));
        uint256 bobSecondRewards = tokensDistributor.pendingRewards(BOB, address(rewardToken));

        console.log("aliceSecondRewards", aliceSecondRewards);
        console.log("bobSecondRewards", bobSecondRewards);

        skip(5 minutes);

        vm.prank(ALICE);
        tokensDistributor.claimRewards(address(rewardToken));

        skip(5 minutes);

        vm.prank(BOB);
        tokensDistributor.claimRewards(address(rewardToken));

        uint128[] memory thirdAmounts = new uint128[](1);
        thirdAmounts[0] = 1_000e18;

        //third reward deposit
        vm.startPrank(protocolAdmin);
        rewardToken.approve(address(tokensDistributor), thirdAmounts[0]);
        tokensDistributor.depositReward(rewardAssets, thirdAmounts);
        vm.stopPrank();

        uint256 aliceThirdRewards = tokensDistributor.pendingRewards(ALICE, address(rewardToken));
        uint256 bobThirdRewards = tokensDistributor.pendingRewards(BOB, address(rewardToken));

        console.log("aliceThirdRewards", aliceThirdRewards);
        console.log("bobThirdRewards", bobThirdRewards);

        skip(5 minutes);

        vm.prank(ALICE);
        tokensDistributor.claimRewards(address(rewardToken));

        skip(5 minutes);

        vm.prank(BOB);
        tokensDistributor.claimRewards(address(rewardToken));

        /**
         * First deposit
         * Alice ; 1,000
         * Bob : 0
         * Second deposit
         * Alice: 500
         * Bob: 500
         * Third deposit
         * Alice :666.66
         * bob : 333.33
         */
        // add assertions
    }
}
