// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Test, console, console2 } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMockToken } from "./mocks/SafeMockToken.sol";
import { USDCMockToken } from "./mocks/USDCMockToken.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { ContractShare } from "src/types/SafeTypes.sol";
import { IUniswapV3Pool } from "src/uniswapV3/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "src/uniswapV3/interfaces/ISwapRouter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SafeYieldRewardDistributorTest is SafeYieldBaseTest {
    /**
     * @notice Shares Info.
     *  1. During Staking Emissions:
     * 35% of the rewards will be distributed to $SAFE stakers.
     * 30% of the rewards will be used for team operations.
     * 35% of the rewards will be used for USDC buybacks and burns.
     *
     * 2. After Staking Emissions:
     * 60% of the rewards will be distributed to $SAFE stakers.
     * 30% of the rewards will be used for team operations.
     * 10% of the rewards will be used for USDC buybacks and burns.
     */
    function testUpdateSafeStakingRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, NOT_ADMIN));
        distributor.updateSafeStaking(makeAddr("newStaking"));
        vm.stopPrank();
    }

    function testRevertIfNewSafeStakingIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector);
        distributor.updateSafeStaking(address(0));
        vm.stopPrank();
    }

    function testUpdateTeamOperationsRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, NOT_ADMIN));
        distributor.updateTeamOperations(makeAddr("newTeamOperations"));
        vm.stopPrank();
    }

    function testRevertIfNewTeamOperationsIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector);
        distributor.updateTeamOperations(address(0));
        vm.stopPrank();
    }

    function testUpdateUsdcBuybackRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, NOT_ADMIN));
        distributor.updateUsdcBuyback(makeAddr("newUsdcBuyback"));
        vm.stopPrank();
    }

    function testRevertIfNewUsdcBuybackIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector);
        distributor.updateUsdcBuyback(address(0));
        vm.stopPrank();
    }

    function testDoesNotDistributeToContractIfCallerNotAdminOrApprovedContract() public {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__NOT_ADMIN_OR_VALID_CONTRACT.selector);
        distributor.distributeToContract(address(staking));
        vm.stopPrank();
    }

    /**
     * @notice If its not during staking emissions, the contract should distribute
     * safe staking gets 60% of the rewards
     * teamOperations gets 30% of the rewards
     * usdcBuyback gets 10% of the rewards
     */
    function testAdminCanDistributeToContractNotDuringStakingEmissions() public {
        uint256 usdcToDistribute = 1_000e6;
        vm.startPrank(protocolAdmin);
        usdc.mint(address(distributor), usdcToDistribute);

        console.log("USDC balance of distributor: ", usdc.balanceOf(address(distributor)));
        skip(5 minutes);

        (,, uint16 teamOperationsShare) =
            distributor.approvedContracts(distributor.contractIndex(address(teamOperations)));
        uint256 initialTeamOperationsUsdcBalance = usdc.balanceOf(address(teamOperations));

        console.log("teamOperationsShare: ", teamOperationsShare);

        console.log("Initial teamOperations balance: ", initialTeamOperationsUsdcBalance);

        uint256 usdcDistributed = distributor.distributeToContract(address(teamOperations));

        console.log("USDC distributed: ", usdcDistributed);

        uint256 expectedTeamOperationsUsdcDistributed = (usdcToDistribute * teamOperationsShare) / distributor.BPS_MAX();

        console.log("Expected teamOperations USDC distributed: ", expectedTeamOperationsUsdcDistributed);

        uint256 finalTeamOperationsUsdcBalance = usdc.balanceOf(address(teamOperations));

        console.log("Final teamOperations balance: ", finalTeamOperationsUsdcBalance);
        vm.stopPrank();

        assertEq(
            usdcDistributed, expectedTeamOperationsUsdcDistributed, "Should distribute the expected amount of USDC"
        );
        assertEq(
            finalTeamOperationsUsdcBalance,
            initialTeamOperationsUsdcBalance + expectedTeamOperationsUsdcDistributed,
            "Balance of teamOperations should be updated"
        );
    }

    /**
     * @notice If its during staking emissions, the contract should distribute
     * safe staking gets 35% value of SAFE tokens as rewards
     * teamOperations gets 30% of the (usdc) rewards
     * usdcBuyback gets 35% of the (usdc) rewards
     */
    function testAdminCanDistributeToContractDuringStakingEmissions() external {
        uint256 usdcToDistribute = 1_000e6;
        vm.startPrank(protocolAdmin);
        usdc.mint(address(distributor), usdcToDistribute);

        console.log("USDC balance of distributor: ", usdc.balanceOf(address(distributor)));
        skip(5 minutes);

        (,, uint16 usdcBuybacksShare) = distributor.approvedContracts(distributor.contractIndex(address(usdcBuyback)));
        uint256 initialUsdcBuybacksUsdcBalance = usdc.balanceOf(address(teamOperations));

        console.log("usdcBuybacksShare: ", usdcBuybacksShare);

        console.log("Initial usdcBuyback balance: ", initialUsdcBuybacksUsdcBalance);

        uint256 usdcDistributed = distributor.distributeToContract(address(usdcBuyback));

        console.log("USDC distributed: ", usdcDistributed);

        uint256 expectedUsdcBuybacksUsdcDistributed = (usdcToDistribute * 10_00) / distributor.BPS_MAX();

        console.log("Expected teamOperations USDC distributed: ", expectedUsdcBuybacksUsdcDistributed);

        uint256 finalUsdcBuybacksUsdcBalance = usdc.balanceOf(address(usdcBuyback));

        console.log("Final UsdcBuyback balance: ", finalUsdcBuybacksUsdcBalance);
        vm.stopPrank();

        vm.prank(protocolAdmin);
        distributor.startStakingEmissions();

        assertEq(usdcBuybacksShare, 10_00, "usdcBuybacksShare should be 3500");

        assertEq(usdcDistributed, expectedUsdcBuybacksUsdcDistributed, "Should distribute the expected amount of USDC");
        assertEq(
            finalUsdcBuybacksUsdcBalance,
            initialUsdcBuybacksUsdcBalance + expectedUsdcBuybacksUsdcDistributed,
            "Balance of usdcBuyback should be updated"
        );
        console.log();
        console.log("Switching to Staking Emissions Shares....................");
        console.log();

        (,, uint16 usdcBuybacksShareAfterSwitch) =
            distributor.approvedContracts(distributor.contractIndex(address(usdcBuyback)));
        //next rewards get minted to distributor
        vm.startPrank(protocolAdmin);
        usdc.mint(address(distributor), usdcToDistribute);

        uint256 expectedUsdcBuybacksUsdcDistributedAfterSwitch =
            (usdcToDistribute * usdcBuybacksShareAfterSwitch) / distributor.BPS_MAX();

        skip(5 minutes);

        uint256 usdcDistributedAfterSwitch = distributor.distributeToContract(address(usdcBuyback));

        console.log("USDC distributed: ", usdcDistributedAfterSwitch);

        uint256 finalUsdcBuybacksUsdcBalanceAfterSwitch = usdc.balanceOf(address(usdcBuyback));

        console.log("Final UsdcBack balance: ", finalUsdcBuybacksUsdcBalanceAfterSwitch);

        assertEq(usdcBuybacksShareAfterSwitch, 3_500, "usdcBuybacksShare should be 3500");

        assertEq(
            usdcDistributedAfterSwitch,
            expectedUsdcBuybacksUsdcDistributedAfterSwitch,
            "Should distribute the expected amount of USDC"
        );
        assertEq(
            finalUsdcBuybacksUsdcBalanceAfterSwitch,
            finalUsdcBuybacksUsdcBalance + expectedUsdcBuybacksUsdcDistributedAfterSwitch,
            "Balance of usdcBuyback should be updated"
        );
    }

    /**
     * @notice If its during staking emissions, the contract should distribute
     * 35% value of the SAFE tokens be minted to staking contract.
     * 30% of the rewards will be used for team operations.
     * 35% of the rewards will be used for USDC buybacks and burns.
     */
    function testAdminCanDistributeToAllContractsDuringStakingEmissions() external {
        uint256 usdcToDistribute = 1_000e6;
        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();

        usdc.mint(address(distributor), usdcToDistribute);

        console.log("USDC balance of distributor: ", usdc.balanceOf(address(distributor)));

        skip(5 minutes);

        (,, uint16 safeStakingShare) = distributor.approvedContracts(distributor.contractIndex(address(staking)));

        (,, uint16 teamOperationsShare) =
            distributor.approvedContracts(distributor.contractIndex(address(teamOperations)));

        (,, uint16 usdcBuybacksShare) = distributor.approvedContracts(distributor.contractIndex(address(usdcBuyback)));

        console.log("safeStakingShareBeforeSwitch: ", safeStakingShare);
        console.log("teamOperationsShareBeforeSwitch: ", teamOperationsShare);
        console.log("usdcBuybacksShareBeforeSwitch: ", usdcBuybacksShare);

        uint256 initialSafeStakingBalance = safeToken.balanceOf(address(staking));

        uint256 initialTeamOperationsUsdcBalance = usdc.balanceOf(address(teamOperations));

        uint256 initialUsdcBuybacksUsdcBalance = usdc.balanceOf(address(usdcBuyback));

        console.log("Initial safeStaking Safe token balance: ", initialSafeStakingBalance);

        console.log("Initial teamOperations usdc balance: ", initialTeamOperationsUsdcBalance);

        console.log("Initial usdcBuyback usdc balance: ", initialUsdcBuybacksUsdcBalance);

        assertEq(distributor.isSafeRewardsDistributed(), false);

        uint256 safeTokenMinted = distributor.distributeToContract(address(staking));

        assertEq(distributor.isSafeRewardsDistributed(), true);

        console.log("SafeToken minted: ", safeTokenMinted);

        uint256 usdcDistributedToTeamOperations = distributor.distributeToContract(address(teamOperations));

        assertEq(distributor.isSafeRewardsDistributed(), false);

        console.log("USDC distributed to teamOperations: ", usdcDistributedToTeamOperations);

        uint256 usdcDistributedToUsdcBuyback = distributor.distributeToContract(address(usdcBuyback));

        console.log("USDC distributed to usdcBuyback: ", usdcDistributedToUsdcBuyback);

        uint256 finalSafeStakingBalance = safeToken.balanceOf(address(staking));

        console.log("Final safeStaking Safe token balance: ", finalSafeStakingBalance);

        uint256 finalTeamOperationsUsdcBalance = usdc.balanceOf(address(teamOperations));

        console.log("Final teamOperations balance: ", finalTeamOperationsUsdcBalance);

        uint256 finalUsdcBuybacksUsdcBalance = usdc.balanceOf(address(usdcBuyback));

        console.log("Final usdcBuyback balance: ", finalUsdcBuybacksUsdcBalance);

        vm.stopPrank();

        assertEq(
            finalSafeStakingBalance,
            initialSafeStakingBalance + safeTokenMinted,
            "Should mint the expected amount of SafeToken"
        );

        assertEq(
            finalTeamOperationsUsdcBalance,
            initialTeamOperationsUsdcBalance + usdcDistributedToTeamOperations,
            "Should distribute the expected amount of USDC to teamOperations"
        );

        assertEq(
            finalUsdcBuybacksUsdcBalance,
            initialUsdcBuybacksUsdcBalance + usdcDistributedToUsdcBuyback,
            "Should distribute the expected amount of USDC to usdcBuyback"
        );
    }

    function testPendingRewards() public {
        vm.startPrank(protocolAdmin);
        usdc.mint(address(distributor), 1_000e6);
        vm.stopPrank();

        skip(5 minutes);
        (,, uint16 teamOperationsShare) =
            distributor.approvedContracts(distributor.contractIndex(address(teamOperations)));

        uint256 expectedTeamOperationsUsdcDistributed = (1_000e6 * uint256(teamOperationsShare)) / distributor.BPS_MAX();

        (uint256 pendingRewards,) = distributor.pendingRewards(address(teamOperations));

        assertEq(
            pendingRewards,
            expectedTeamOperationsUsdcDistributed,
            "Should return the expected amount of pending rewards"
        );
    }

    /**
     * @notice If its during staking emissions, the contract should distribute
     * 35% value of the SAFE tokens be minted to staking contract.
     * so the pending rewards during staking emissions should be in SAFE tokens
     */
    function testPendingRewardsForSafeStakingDuringStakingEmissions() public {
        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();
        usdc.mint(address(distributor), 1_000e6);
        vm.stopPrank();

        skip(5 minutes);
        (,, uint16 safeStakingShare) = distributor.approvedContracts(distributor.contractIndex(address(staking)));

        uint256 expectedSafeStakingRewards = (1_000e6 * uint256(safeStakingShare)) / distributor.BPS_MAX();

        uint256 pendingSafeToken = (expectedSafeStakingRewards * 1e18) / 1e6;

        (, uint256 pendingRewards) = distributor.pendingRewards(address(staking));

        assertEq(pendingRewards, pendingSafeToken, "Should return the expected amount of pending rewards");
    }

    function test_distributeWithStakingEmissionLive() public {
        vm.startPrank(protocolAdmin);

        distributor.startStakingEmissions();

        vm.stopPrank();

        skip(2 hours);

        usdc.mint(address(distributor), 10_000e6);

        skip(1 hours);

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        console.log("UsdcBuyBack Distributed");

        vm.prank(address(teamOperations));
        distributor.distributeToContract(address(teamOperations));

        vm.startPrank(address(staking));
        distributor.distributeToContract(address(staking));
        vm.stopPrank();

        console.log("Balance of Team Operations: ", usdc.balanceOf(address(teamOperations)));
        console.log("Balance of USDC Buyback: ", usdc.balanceOf(address(usdcBuyback)));
        console.log("Balance of Staking: ", safeToken.balanceOf(address(staking)));

        skip(2 hours);
        usdc.mint(address(distributor), 10_000e6);

        console.log();
        console.log("************** Second Distribution **************");
        console.log();
        skip(1 hours);

        vm.prank(address(staking));
        distributor.distributeToContract(address(staking));

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        vm.prank(address(teamOperations));
        distributor.distributeToContract(address(teamOperations));

        console.log("New Balance of Team Operations: ", usdc.balanceOf(address(teamOperations)));
        console.log("New Balance of USDC Buyback: ", usdc.balanceOf(address(usdcBuyback)));
        console.log("New Balance of Staking: ", safeToken.balanceOf(address(staking)));

        // //assertions
        assertEq(usdc.balanceOf(address(usdcBuyback)), 7_000e6);
        assertEq(safeToken.balanceOf(address(staking)), 7_000e18);
        assertEq(usdc.balanceOf(address(teamOperations)), 6_000e6);
        // assertEq(usdc.balanceOf(address(distributor)), 10_500e6);
    }

    function test_distributeWithStakingEmissionNotStarted() public {
        usdc.mint(address(distributor), 10_000e6);
        vm.startPrank(address(staking));
        distributor.distributeToContract(address(staking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        skip(2 hours);
        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(address(teamOperations));
        distributor.distributeToContract(address(teamOperations));

        skip(1 hours);
        vm.startPrank(address(staking));
        distributor.distributeToContract(address(staking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        console.log("Balance of Team Operations: ", usdc.balanceOf(address(teamOperations)));
        console.log("Balance of USDC Buyback: ", usdc.balanceOf(address(usdcBuyback)));
        console.log("Balance of Staking: ", usdc.balanceOf(address(staking)));

        //teamOperations get 30% of 30_000e6
        //usdcbuyback get 10% of 30_000e6
        //safeStaking get 60% of 30_000e6

        //assertions
        // assertEq(usdc.balanceOf(address(usdcBuyback)), 3_000e6);
        // assertEq(usdc.balanceOf(address(staking)), 18_000e6);
        // assertEq(usdc.balanceOf(address(teamOperations)), 9_000e6);
        // assertEq(safeToken.balanceOf(address(staking)), 0);
        // assertEq(usdc.balanceOf(address(distributor)), 0);
    }

    function test_Fuzz_ContractShouldReceiveUSdcRewardsAfterSwitchingToSafeRewards(uint256 amountToDistribute) public {
        amountToDistribute = bound(amountToDistribute, 10_000e6, 100_000e6);
        usdc.mint(address(distributor), amountToDistribute);
        console.log();
        console.log("USDC Rewards");
        console.log("Total Revenue", usdc.balanceOf(address(distributor)));
        console.log();
        skip(5 minutes);

        (uint256 stakingPendingUSDC, uint256 stakingPendingSafeRewards) = distributor.pendingRewards(address(staking));
        (uint256 teamOperationsPendingUSDC, uint256 teamOperationsPendingSafeRewards) =
            distributor.pendingRewards(teamOperations);

        (uint256 usdcBuyBackPendingUSDC, uint256 usdcBuyBackPendingSafeRewards) =
            distributor.pendingRewards(usdcBuyback);

        uint256 amountToDistribute_ = amountToDistribute;

        uint256 calculateStakingPendingRewards = (6_000 * amountToDistribute_) / 10_000;
        uint256 calculateTeamOpPendingRewards = (3_000 * amountToDistribute_) / 10_000;
        uint256 calculateUsdcBuyBackPendingRewards = (1_000 * amountToDistribute_) / 10_000;

        assertApproxEqAbs(stakingPendingUSDC, calculateStakingPendingRewards, 1e4);
        assertApproxEqAbs(teamOperationsPendingUSDC, calculateTeamOpPendingRewards, 1e4);
        assertApproxEqAbs(usdcBuyBackPendingUSDC, calculateUsdcBuyBackPendingRewards, 1e4);

        console.log("Staking Pending Safe Rewards", stakingPendingSafeRewards);
        console.log("Staking Pending USDC Rewards", stakingPendingUSDC);

        console.log("teamOperations Pending Safe Rewards", teamOperationsPendingSafeRewards);
        console.log("teamOperations Pending USDC Rewards", teamOperationsPendingUSDC);

        console.log("usdcBuyback Pending Safe Rewards", usdcBuyBackPendingSafeRewards);
        console.log("usdcBuyback Pending USDC Rewards", usdcBuyBackPendingUSDC);

        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();
        vm.stopPrank();

        usdc.mint(address(distributor), amountToDistribute_);

        skip(5 minutes);

        console.log();
        console.log("Switching To Staking Emissions-Safe Rewards");
        console.log("Total Revenue", usdc.balanceOf(address(distributor)));
        console.log();

        // uint256 newBalance = usdc.balanceOf(address(distributor));

        (uint256 stakingPendingUSDC2, uint256 stakingPendingSafeRewards2) = distributor.pendingRewards(address(staking));
        (uint256 teamOperationsPendingUSDC2, uint256 teamOperationsPendingSafeRewards2) =
            distributor.pendingRewards(teamOperations);
        (uint256 usdcBuyBackPendingUSDC2, /*uint256 usdcBuyBackPendingSafeRewards2*/ ) =
            distributor.pendingRewards(usdcBuyback);

        console.log("Staking Pending Safe Rewards", stakingPendingSafeRewards2);
        console.log("Staking Pending USDC Rewards", stakingPendingUSDC2);

        console.log("teamOperations Pending Safe Rewards", teamOperationsPendingSafeRewards2);
        console.log("teamOperations Pending USDC Rewards", teamOperationsPendingUSDC2);

        // console.log("usdcBuyback Pending Safe Rewards", usdcBuyBackPendingSafeRewards2);
        console.log("usdcBuyback Pending USDC Rewards", usdcBuyBackPendingUSDC2);

        // uint256 calculateStakingPendingRewards2 = (6_000 * newBalance) / 10_000;
        // uint256 calculateTeamOpPendingRewards2 = (3_000 * newBalance) / 10_000;
        // uint256 calculateUsdcBuyBackPendingRewards2 = (3_500 * newBalance) / 10_000;

        // console.log("calculateTeamOpPendingRewards2", calculateTeamOpPendingRewards2);
        // console.log("calculateUsdcBuyBackPendingRewards2", calculateUsdcBuyBackPendingRewards2);

        vm.startPrank(protocolAdmin);
        distributor.setSafeTransferred(11_000_000e18);
        distributor.endStakingEmissions();
        vm.stopPrank();

        uint256 amountToDistribute__ = amountToDistribute_;

        usdc.mint(address(distributor), amountToDistribute__);

        console.log();
        console.log("Switching To Staking Emissions-USDC Rewards");
        console.log("Total Revenue", usdc.balanceOf(address(distributor)));
        console.log();

        skip(5 minutes);

        (uint256 stakingPendingUSDC3, uint256 stakingPendingSafeRewards3) = distributor.pendingRewards(address(staking));
        (uint256 teamOperationsPendingUSDC3, uint256 teamOperationsPendingSafeRewards3) =
            distributor.pendingRewards(teamOperations);
        (uint256 usdcBuyBackPendingUSDC3, uint256 usdcBuyBackPendingSafeRewards3) =
            distributor.pendingRewards(usdcBuyback);

        console.log("Staking Pending Safe Rewards", stakingPendingSafeRewards3);
        console.log("Staking Pending USDC Rewards", stakingPendingUSDC3);

        console.log("teamOperations Pending Safe Rewards", teamOperationsPendingSafeRewards3);
        console.log("teamOperations Pending USDC Rewards", teamOperationsPendingUSDC3);

        console.log("usdcBuyback Pending Safe Rewards", usdcBuyBackPendingSafeRewards3);
        console.log("usdcBuyback Pending USDC Rewards", usdcBuyBackPendingUSDC3);

        //assertions
    }

    function test_CheckTWAP() public {
        // console.log("uniswapV3 pool", distributor.safeYieldPool());

        // uint160 initialPrice = 1;

        // uint256 sqrtPrice = Math.sqrt(initialPrice);

        // uint256 QX96 = 2 ** 96;

        // uint160 sqrtPriceX96_ = uint160(sqrtPrice * QX96) - 1;

        // vm.startPrank(USDC_WHALE);

        // safeToken.approve(address(swapRouter), 1_000e18);

        // ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
        //     tokenIn: address(safeToken),
        //     tokenOut: USDC,
        //     fee: 500,
        //     recipient: USDC_WHALE,
        //     deadline: block.timestamp + 100,
        //     amountIn: 1_000e18,
        //     amountOutMinimum: 1e6,
        //     sqrtPriceLimitX96: 0
        // });

        // swapRouter.exactInputSingle(params);

        // skip(block.number + 1);

        // console.log(
        //     "Price of Safe", twap.getEstimateAmountOut(distributor.safeYieldPool(), address(safeToken), 1e18, 60)
        // );
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_updatesTheTeamOperationsAddress(address newTeamOperations) public {
        vm.assume(newTeamOperations != address(0));
        vm.assume(newTeamOperations != distributor.teamOperations());
        uint256 teamOperationsIndex = distributor.contractIndex(teamOperations);
        (int256 initialShareDebt, address initialContract, uint16 initialShare) =
            distributor.approvedContracts(teamOperationsIndex);
        vm.startPrank(protocolAdmin);
        distributor.updateTeamOperations(newTeamOperations);
        vm.stopPrank();

        address newTeamOperationsSetup = distributor.teamOperations();

        (int256 finalShareDebt, address finalContract, uint16 finalShare) =
            distributor.approvedContracts(teamOperationsIndex);
        uint256 oldTeamOperationsAddressIndex = distributor.contractIndex(teamOperations);
        uint256 newTeamOperationsAddressIndex = distributor.contractIndex(newTeamOperations);

        assertEq(
            newTeamOperationsSetup,
            newTeamOperations,
            "New teamOperations address should be updated in the contract state"
        );
        // Contract address should be updated
        assertNotEq(initialContract, finalContract, "New teamOperations address should not be the same as the old one");
        assertEq(finalContract, newTeamOperations, "New teamOperations address should be the same as the one passed in");

        // Everything else remains the same
        assertEq(initialShareDebt, finalShareDebt, "Share debt should remain the same");
        assertEq(initialShare, finalShare, "Share should remain the same");

        assertEq(oldTeamOperationsAddressIndex, 0, "Old teamOperations address should be at index 0 (Deleted)");
        assertEq(
            newTeamOperationsAddressIndex, teamOperationsIndex, "New teamOperations address should be at the same index"
        );
    }

    function test_fuzz_addContractRevertsForUpdatedAllocationsAndApprovedContractsLengthMismatch(
        ContractShare memory newContractInfo,
        ContractShare[] memory updatedAllocations
    ) public {
        uint256 defaultContractCount = 3;
        vm.assume(newContractInfo.contract_ != address(0));
        vm.assume(updatedAllocations.length != defaultContractCount);

        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__ARRAY_LENGTH_MISMATCH.selector);
        distributor.addContract(newContractInfo, updatedAllocations);
    }

    function test_fuzz_addContractRevertsIfNewContractShareIsZero(address newContract) public {
        vm.assume(newContract != address(0));
        (ContractShare memory newContractInfo, ContractShare[] memory updatedAllocations) =
            _prepareAddContract(newContract);
        newContractInfo.share = 0;

        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__INVALID_SHARE.selector);
        distributor.addContract(newContractInfo, updatedAllocations);
    }

    function test_fuzz_addContractRevertsIfOrderOfContractsMismatch(address newContract) public {
        vm.assume(newContract != address(0));
        vm.assume(newContract != distributor.teamOperations());
        vm.assume(newContract != distributor.safeStaking());
        vm.assume(newContract != distributor.usdcBuyback());
        (ContractShare memory newContractInfo, ContractShare[] memory updatedAllocations) =
            _prepareAddContract(newContract);
        ContractShare memory temp = updatedAllocations[0];
        updatedAllocations[0] = updatedAllocations[1]; // This will mess up the order
        updatedAllocations[1] = temp;

        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldRewardDistributor.SYRD__INVALID_CONTRACT.selector);
        distributor.addContract(newContractInfo, updatedAllocations);
        vm.stopPrank();
    }

    function test_fuzz_addContractUpdatesTheSharesFromTheUpdatedAllocation(address newContract) public {
        vm.assume(newContract != address(0));
        vm.assume(newContract != distributor.teamOperations());
        vm.assume(newContract != distributor.safeStaking());
        vm.assume(newContract != distributor.usdcBuyback());
        (ContractShare memory newContractInfo, ContractShare[] memory updatedAllocations) =
            _prepareAddContract(newContract);

        uint16 totalShare = newContractInfo.share;
        vm.startPrank(protocolAdmin);
        ///@dev send some usdc to the distributor to simulate a reward distribution and update accumulatedUsdcPerContract
        usdc.mint(address(distributor), 1_000e6);
        distributor.addContract(newContractInfo, updatedAllocations);
        uint256 accumulatedUsdPerContract = distributor.accumulatedUsdcPerContract();
        console.log("accumulatedUsdPerContract: ", accumulatedUsdPerContract);
        vm.stopPrank();

        uint256 indexOfNewContract = distributor.contractIndex(newContract);
        assertEq(indexOfNewContract, updatedAllocations.length, "New contract should be at the end of the array");

        for (uint8 i = 0; i < updatedAllocations.length; ++i) {
            (int256 shareDebt,, uint16 updatedShare) = distributor.approvedContracts(i);
            uint16 expectedShare = updatedAllocations[i].share;
            totalShare += updatedShare;
            int256 expectedShareDebt = int256(updatedAllocations[i].share * accumulatedUsdPerContract);

            assertEq(updatedShare, expectedShare, "Share should be updated to the new value");
            assertEq(shareDebt, expectedShareDebt, "Share debt should be the expected value");
        }

        (int256 newContractShareDebt,,) = distributor.approvedContracts(updatedAllocations.length);
        assertEq(totalShare, distributor.BPS_MAX(), "Total share should be 10_000");
        assertEq(
            uint256(newContractInfo.share * accumulatedUsdPerContract),
            uint256(newContractShareDebt),
            "Share debt should be the expected value"
        );
    }

    function test_fuzz_removeContract(address newContract) public {
        vm.assume(newContract != address(0));
        vm.assume(newContract != distributor.teamOperations());
        vm.assume(newContract != distributor.safeStaking());
        vm.assume(newContract != distributor.usdcBuyback());

        ContractShare[] memory updatedAllocations = _prepareRemoveContract(newContract, false);

        uint16 totalShare = 0;
        vm.startPrank(protocolAdmin);
        ///@dev send some usdc to the distributor to simulate a reward distribution and update accumulatedUsdcPerContract
        usdc.mint(address(distributor), 1_000e6);

        distributor.removeContract(newContract, updatedAllocations);
        uint256 accumulatedUsdPerContract = distributor.accumulatedUsdcPerContract();
        vm.stopPrank();

        uint256 indexOfNewContract = distributor.contractIndex(newContract);
        assertEq(indexOfNewContract, 0, "New contract should be removed from the array");

        ContractShare[] memory currentContracts = distributor.getAllContracts();

        for (uint8 i = 0; i < currentContracts.length; ++i) {
            int256 shareDebt = currentContracts[i].shareDebt;
            uint16 updatedShare = currentContracts[i].share;

            uint16 expectedShare = updatedAllocations[i].share;
            totalShare += updatedShare;
            int256 expectedShareDebt = int256(updatedAllocations[i].share * accumulatedUsdPerContract);

            assertEq(updatedShare, expectedShare, "Share should be updated to the new value");
            assertEq(shareDebt, expectedShareDebt, "Share debt should be the expected value");
        }

        assertEq(totalShare, distributor.BPS_MAX(), "Total share should be 10_000");
    }

    /**
     * @dev adds a contract to the reward distributor with a share of 1000 subtracted from the vault's share
     * @dev do not call more than 5 times consecutively if each iteration adds a new contract to the reward distributor.
     */
    function _prepareAddContract(address newContract)
        internal
        view
        returns (ContractShare memory, ContractShare[] memory)
    {
        ContractShare[] memory currentContracts = distributor.getAllContracts();

        currentContracts[0].share -= 1_000;

        ///reallocate 1k to new contract from the vault
        console.log("currentContracts[0].share", currentContracts[0].share);
        ContractShare memory newContractInfo = ContractShare({ contract_: newContract, share: 1_000, shareDebt: 0 });

        return (newContractInfo, currentContracts);
    }

    function _prepareRemoveContract(address contractToRemove, bool isApproved)
        internal
        returns (ContractShare[] memory)
    {
        (ContractShare memory newContractInfo, ContractShare[] memory updatedAllocations) =
            _prepareAddContract(contractToRemove);

        if (!isApproved) {
            vm.startPrank(protocolAdmin);
            distributor.addContract(newContractInfo, updatedAllocations);
            vm.stopPrank();
        }

        skip(5 minutes);

        ContractShare[] memory currentContracts = distributor.getAllContracts();
        uint256 indexOfContractToRemove = distributor.contractIndex(contractToRemove);
        currentContracts[indexOfContractToRemove].share = 0;
        ///set the share to 0 to remove the contract
        currentContracts[0].share += 1_000;
        ///reallocate 1k to the vault from the removed contract
        return currentContracts;
    }
}
