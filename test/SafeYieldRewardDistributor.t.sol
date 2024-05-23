// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;
import {Test, console} from "forge-std/Test.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMockToken} from "./mocks/SafeMockToken.sol";
import {USDCMockToken} from "./mocks/USDCMockToken.sol";
import {SafeYieldRewardDistributor} from "src/SafeYieldRewardDistributor.sol";
import {SafeYieldBaseTest} from "./SafeYieldBaseTest.t.sol";

contract SafeYieldRewardDistributorTest is SafeYieldBaseTest {
    function testUpdateSafeStakingRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                NOT_ADMIN
            )
        );
        distributor.updateSafeStaking(makeAddr("newStaking"));
        vm.stopPrank();
    }

    function testRevertIfNewSafeStakingIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector
            )
        );
        distributor.updateSafeStaking(address(0));
        vm.stopPrank();
    }

    function testUpdateTeamOperationsRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                NOT_ADMIN
            )
        );
        distributor.updateTeamOperations(makeAddr("newTeamOperations"));
        vm.stopPrank();
    }

    function testRevertIfNewTeamOperationsIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector
            )
        );
        distributor.updateTeamOperations(address(0));
        vm.stopPrank();
    }

    function testUpdateUsdcBuybackRevertsIfCallerIsNotTheOwner() external {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                NOT_ADMIN
            )
        );
        distributor.updateUsdcBuyback(makeAddr("newUsdcBuyback"));
        vm.stopPrank();
    }

    function testRevertIfNewUsdcBuybackIsZero() external {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeYieldRewardDistributor.SYRD__ZERO_ADDRESS.selector
            )
        );
        distributor.updateUsdcBuyback(address(0));
        vm.stopPrank();
    }

    function testDoesNotDistributeToContractIfCallerNotAdminOrApprovedContract()
        public
    {
        vm.startPrank(NOT_ADMIN);
        vm.expectRevert(
            SafeYieldRewardDistributor
                .SYRD__NOT_ADMIN_OR_VALID_CONTRACT
                .selector
        );
        distributor.distributeToContract(address(staking));
        vm.stopPrank();
    }

    /**
     * @notice If its not during staking emissions, the contract should distribute
     * safe staking gets 60% of the rewards
     * teamOperations gets 30% of the rewards
     * usdcBuyback gets 10% of the rewards
     */
    function testAdminCanDistributeToContractNotDuringStakingEmissions()
        public
    {
        uint256 usdcToDistribute = 1_000e6;
        vm.startPrank(protocolAdmin);
        usdc.mint(address(distributor), usdcToDistribute);

        console.log(
            "USDC balance of distributor: ",
            usdc.balanceOf(address(distributor))
        );
        skip(5 minutes);

        (, , uint16 teamOperationsShare) = distributor.approvedContracts(
            distributor.contractIndex(address(teamOperations))
        );
        uint256 initialTeamOperationsUsdcBalance = usdc.balanceOf(
            address(teamOperations)
        );

        console.log("teamOperationsShare: ", teamOperationsShare);

        console.log(
            "Initial teamOperations balance: ",
            initialTeamOperationsUsdcBalance
        );

        uint256 usdcDistributed = distributor.distributeToContract(
            address(teamOperations)
        );

        console.log("USDC distributed: ", usdcDistributed);

        uint256 expectedTeamOperationsUsdcDistributed = (usdcToDistribute *
            teamOperationsShare) / distributor.BPS_MAX();

        console.log(
            "Expected teamOperations USDC distributed: ",
            expectedTeamOperationsUsdcDistributed
        );

        uint256 finalTeamOperationsUsdcBalance = usdc.balanceOf(
            address(teamOperations)
        );

        console.log(
            "Final teamOperations balance: ",
            finalTeamOperationsUsdcBalance
        );
        vm.stopPrank();

        assertEq(
            usdcDistributed,
            expectedTeamOperationsUsdcDistributed,
            "Should distribute the expected amount of USDC"
        );
        assertEq(
            finalTeamOperationsUsdcBalance,
            initialTeamOperationsUsdcBalance +
                expectedTeamOperationsUsdcDistributed,
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

        console.log(
            "USDC balance of distributor: ",
            usdc.balanceOf(address(distributor))
        );
        skip(5 minutes);

        (, , uint16 usdcBuybacksShare) = distributor.approvedContracts(
            distributor.contractIndex(address(usdcBuyback))
        );
        uint256 initialUsdcBuybacksUsdcBalance = usdc.balanceOf(
            address(teamOperations)
        );

        console.log("usdcBuybacksShare: ", usdcBuybacksShare);

        console.log(
            "Initial usdcBuyback balance: ",
            initialUsdcBuybacksUsdcBalance
        );

        uint256 usdcDistributed = distributor.distributeToContract(
            address(usdcBuyback)
        );

        console.log("USDC distributed: ", usdcDistributed);

        uint256 expectedUsdcBuybacksUsdcDistributed = (usdcToDistribute *
            10_00) / distributor.BPS_MAX();

        console.log(
            "Expected teamOperations USDC distributed: ",
            expectedUsdcBuybacksUsdcDistributed
        );

        uint256 finalUsdcBuybacksUsdcBalance = usdc.balanceOf(
            address(usdcBuyback)
        );

        console.log(
            "Final UsdcBuyback balance: ",
            finalUsdcBuybacksUsdcBalance
        );
        vm.stopPrank();

        vm.prank(protocolAdmin);
        distributor.startStakingEmissions();

        assertEq(usdcBuybacksShare, 10_00, "usdcBuybacksShare should be 3500");

        assertEq(
            usdcDistributed,
            expectedUsdcBuybacksUsdcDistributed,
            "Should distribute the expected amount of USDC"
        );
        assertEq(
            finalUsdcBuybacksUsdcBalance,
            initialUsdcBuybacksUsdcBalance +
                expectedUsdcBuybacksUsdcDistributed,
            "Balance of usdcBuyback should be updated"
        );
        console.log();
        console.log(
            "Switching to Staking Emissions Shares...................."
        );
        console.log();

        (, , uint16 usdcBuybacksShareAfterSwitch) = distributor
            .approvedContracts(distributor.contractIndex(address(usdcBuyback)));
        //next rewards get minted to distributor
        vm.startPrank(protocolAdmin);
        usdc.mint(address(distributor), usdcToDistribute);

        uint256 expectedUsdcBuybacksUsdcDistributedAfterSwitch = (usdcToDistribute *
                usdcBuybacksShareAfterSwitch) / distributor.BPS_MAX();

        skip(5 minutes);

        uint256 usdcDistributedAfterSwitch = distributor.distributeToContract(
            address(usdcBuyback)
        );

        console.log("USDC distributed: ", usdcDistributedAfterSwitch);

        uint256 finalUsdcBuybacksUsdcBalanceAfterSwitch = usdc.balanceOf(
            address(usdcBuyback)
        );

        console.log(
            "Final UsdcBack balance: ",
            finalUsdcBuybacksUsdcBalanceAfterSwitch
        );

        assertEq(
            usdcBuybacksShareAfterSwitch,
            3_500,
            "usdcBuybacksShare should be 3500"
        );

        assertEq(
            usdcDistributedAfterSwitch,
            expectedUsdcBuybacksUsdcDistributedAfterSwitch,
            "Should distribute the expected amount of USDC"
        );
        assertEq(
            finalUsdcBuybacksUsdcBalanceAfterSwitch,
            finalUsdcBuybacksUsdcBalance +
                expectedUsdcBuybacksUsdcDistributedAfterSwitch,
            "Balance of usdcBuyback should be updated"
        );
    }

    /**
     * @notice If its during staking emissions, the contract should distribute
     * 35% value of the SAFE tokens be minted to staking contract.
     */
    function testAdminCanDistributeToSafeStakingDuringStakingEmissions()
        external
    {
        uint256 usdcToDistribute = 1_000e6;
        vm.startPrank(protocolAdmin);
        distributor.startStakingEmissions();

        usdc.mint(address(distributor), usdcToDistribute);

        console.log(
            "USDC balance of distributor: ",
            usdc.balanceOf(address(distributor))
        );

        skip(5 minutes);

        (, , uint16 safeStakingShare) = distributor.approvedContracts(
            distributor.contractIndex(address(staking))
        );

        console.log("safeStakingShareBeforeSwitch: ", safeStakingShare);

        uint256 initialSafeStakingBalance = safeToken.balanceOf(
            address(staking)
        );

        console.log(
            "Initial safeStaking Safe token balance: ",
            initialSafeStakingBalance
        );

        uint256 safeTokenMinted = distributor.distributeToContract(
            address(staking)
        );

        console.log("SafeToken minted: ", safeTokenMinted);

        uint256 finalSafeStakingBalance = safeToken.balanceOf(address(staking));

        console.log(
            "Final safeStaking Safe token balance: ",
            finalSafeStakingBalance
        );

        vm.stopPrank();

        assertEq(
            finalSafeStakingBalance,
            initialSafeStakingBalance + safeTokenMinted,
            "Should mint the expected amount of SafeToken"
        );
    }

    function test_MaxMintLimit() public {
        assertEq(safeToken.minterLimits(address(distributor)), 11_000_000e18);

        vm.prank(address(distributor));
        safeToken.mint(address(distributor), 1_000_000e18);

        assertEq(safeToken.minterLimits(address(distributor)), 10_000_000e18);
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
    35% of the rewards will be distributed to $SAFE stakers.
    30% of the rewards will be used for team operations.
    35% of the rewards will be used for USDC buybacks and burns.

    2. After Staking Emissions:
    60% of the rewards will be distributed to $SAFE stakers.
    30% of the rewards will be used for team operations.
    10% of the rewards will be used for USDC buybacks and burns.
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
}
