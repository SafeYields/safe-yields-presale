// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMockToken } from "./mocks/SafeMockToken.sol";
import { USDCMockToken } from "./mocks/USDCMockToken.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";
import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { ContractShare } from "src/types/SafeTypes.sol";

contract SafeYieldRewardDistributorTest is SafeYieldBaseTest {
    function testUpdateSafeStakingRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, NOT_ADMIN));
        distributor.updateSafeStaking(makeAddr("newStaking"));
        vm.stopPrank();
    }

    function testRevertIfNewSafeStakingIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(abi.encodeWithSelector(SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector));
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
        vm.expectRevert(abi.encodeWithSelector(SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector));
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
        vm.expectRevert(abi.encodeWithSelector(SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector));
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

        uint256 safeTokenMinted = distributor.distributeToContract(address(staking));

        console.log("SafeToken minted: ", safeTokenMinted);

        uint256 usdcDistributedToTeamOperations = distributor.distributeToContract(address(teamOperations));

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

        uint256 pendingRewards = distributor.pendingRewards(address(teamOperations));

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

        uint256 pendingRewards = distributor.pendingRewards(address(staking));

        assertEq(pendingRewards, pendingSafeToken, "Should return the expected amount of pending rewards");
    }

    function test_MaxMintLimit() public {
        assertEq(safeToken.allocationLimits(address(distributor)), 11_000_000e18);

        vm.prank(address(distributor));
        safeToken.mint(1_000_000e18);

        assertEq(safeToken.allocationLimits(address(distributor)), 10_000_000e18);
    }

    function test_distributeWithStakingEmissionLive() public {
        vm.startPrank(protocolAdmin);

        distributor.startStakingEmissions();

        distributor.switchSharesPerPhase();

        vm.stopPrank();

        usdc.mint(address(distributor), 10_000e6);

        // vm.startPrank(address(safeStaking));
        // distributor.distributeToContract(address(safeStaking));
        skip(2 hours);

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

        /**
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

        //usdcbuyback get 35% of 30_000e6 if startStakingEmissions is called and
        //10% of 30_000e6 if startStakingEmissions is not called

        //safeStaking get 35% of 30_000e6 if startStakingEmissions is called and
        //60% of 30_000e6 if startStakingEmissions is not called

        //teamOperations get 30% of 30_000e6 if startStakingEmissions is called and
        //30% of 30_000e6 if startStakingEmissions is not called

        //reward distributor balance should be 0 after all distributions if startStakingEmissions is not
        //called and 35% of 30_000e6 if startStakingEmissions is called

        //assertions
        assertEq(usdc.balanceOf(address(usdcBuyback)), 10_500e6);
        assertEq(safeToken.balanceOf(address(staking)), 10_500e18);
        assertEq(usdc.balanceOf(address(teamOperations)), 9_000e6);
        assertEq(usdc.balanceOf(address(distributor)), 10_500e6);
    }

    function test_distributeWithStakingEmissionNotStarted() public {
        usdc.mint(address(distributor), 10_000e6);

        // vm.startPrank(address(safeStaking));
        // distributor.distributeToContract(address(safeStaking));
        skip(2 hours);

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

        //teamOperations get 30% of 30_000e6
        //usdcbuyback get 10% of 30_000e6
        //safeStaking get 60% of 30_000e6

        //assertions
        assertEq(usdc.balanceOf(address(usdcBuyback)), 3_000e6);
        assertEq(usdc.balanceOf(address(staking)), 18_000e6);
        assertEq(usdc.balanceOf(address(teamOperations)), 9_000e6);
        assertEq(safeToken.balanceOf(address(staking)), 0);
        assertEq(usdc.balanceOf(address(distributor)), 0);
    }

    function test_endEmissionShouldSwitchToNormalRewardShares() public {
        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();
        vm.stopPrank();

        usdc.mint(address(distributor), 31_000_000e6);

        skip(5 minutes);

        vm.startPrank(address(staking));
        distributor.distributeToContract(address(staking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        skip(5 minutes);

        vm.startPrank(address(teamOperations));
        distributor.distributeToContract(address(teamOperations));
        vm.stopPrank();

        vm.prank(address(staking));
        distributor.distributeToContract(address(staking));

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        //assertions
        assertEq(usdc.balanceOf(address(usdcBuyback)), 10_850_000e6);
        assertEq(safeToken.balanceOf(address(staking)), 10_850_000e18);
        assertEq(usdc.balanceOf(address(teamOperations)), 9_300_000e6);
        assertEq(usdc.balanceOf(address(distributor)), 10_850_000e6);

        usdc.mint(address(distributor), 428_571.42e6);

        skip(5 minutes);

        vm.prank(address(staking));
        distributor.distributeToContract(address(staking));

        uint256 safeTokensRemaining = distributor.MAX_STAKING_EMISSIONS() - distributor.safeMinted();

        console.log("safeTokensRemaining: ", safeTokensRemaining);

        vm.startPrank(protocolAdmin);
        distributor.endStakingEmissions();
        vm.stopPrank();

        usdc.mint(address(distributor), 10_000e6);

        skip(5 minutes);

        vm.startPrank(address(staking));
        distributor.distributeToContract(address(staking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        skip(5 minutes);

        //assert shares after staking emissions
        (,, uint16 usdcBuybacksShare) = distributor.approvedContracts(distributor.contractIndex(address(usdcBuyback)));

        (,, uint16 safeStakingShare) = distributor.approvedContracts(distributor.contractIndex(address(staking)));

        (,, uint16 teamOperationsShare) =
            distributor.approvedContracts(distributor.contractIndex(address(teamOperations)));

        assertEq(usdcBuybacksShare, 10_00);
        assertEq(safeStakingShare, 60_00);
        assertEq(teamOperationsShare, 30_00);
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
