// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;
import {Test, console} from "forge-std/Test.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMockToken} from "./mocks/SafeMockToken.sol";
import {USDCMockToken} from "./mocks/USDCMockToken.sol";
import {SafeYieldRewardDistributor} from "src/SafeYieldRewardDistributor.sol";

contract SafeYieldRewardDistributorTest is Test {
    USDCMockToken public usdc;
    SafeMockToken public safeToken;
    SafeYieldRewardDistributor public distributor;
    address public teamOperations = makeAddr("teamOperations");
    address public usdcBuyback = makeAddr("usdcBuyback");
    address public safeStaking = makeAddr("safeStaking");
    address public protocolAdmin = makeAddr("protocolAdmin");

    function setUp() public {
        usdc = new USDCMockToken("USDC", "USDC", 6);
        safeToken = new SafeMockToken("SafeToken", "SAFE", 18);

        distributor = new SafeYieldRewardDistributor(
            address(safeToken),
            address(usdc),
            teamOperations,
            usdcBuyback,
            safeStaking,
            protocolAdmin
        );
        safeToken.grantRole(safeToken.MINTER_ROLE(), address(distributor));
        safeToken.setMinterLimit(address(distributor), 11_000_000e18);
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
        vm.startPrank(address(safeStaking));
        distributor.distributeToContract(address(safeStaking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        skip(2 hours);
        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(address(teamOperations));
        distributor.distributeToContract(address(teamOperations));

        skip(1 hours);
        vm.startPrank(address(safeStaking));
        distributor.distributeToContract(address(safeStaking));
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
        assertEq(safeToken.balanceOf(address(safeStaking)), 10_500e18);
        assertEq(usdc.balanceOf(address(teamOperations)), 9_000e6);
        assertEq(usdc.balanceOf(address(distributor)), 10_500e6);
    }

    function test_distributeWithStakingEmissionNotStarted() public {
        usdc.mint(address(distributor), 10_000e6);

        // vm.startPrank(address(safeStaking));
        // distributor.distributeToContract(address(safeStaking));
        skip(2 hours);

        usdc.mint(address(distributor), 10_000e6);
        vm.startPrank(address(safeStaking));
        distributor.distributeToContract(address(safeStaking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        skip(2 hours);
        usdc.mint(address(distributor), 10_000e6);

        vm.startPrank(address(teamOperations));
        distributor.distributeToContract(address(teamOperations));

        skip(1 hours);
        vm.startPrank(address(safeStaking));
        distributor.distributeToContract(address(safeStaking));
        vm.stopPrank();

        vm.prank(address(usdcBuyback));
        distributor.distributeToContract(address(usdcBuyback));

        //teamOperations get 30% of 30_000e6
        //usdcbuyback get 10% of 30_000e6
        //safeStaking get 60% of 30_000e6

        //assertions
        assertEq(usdc.balanceOf(address(usdcBuyback)), 3_000e6);
        assertEq(usdc.balanceOf(address(safeStaking)), 18_000e6);
        assertEq(usdc.balanceOf(address(teamOperations)), 9_000e6);
        assertEq(safeToken.balanceOf(address(safeStaking)), 0);
        assertEq(usdc.balanceOf(address(distributor)), 0);
    }
}
