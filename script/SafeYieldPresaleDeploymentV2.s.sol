// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { SafeToken } from "src/SafeToken.sol";
import { SafeYieldTWAP } from "src/SafeYieldTWAP.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";
import { ContractShare } from "src/types/SafeTypes.sol";

contract SafeYieldPresaleDeploymentV2 is Script {
    uint128 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;

    uint128 public constant STAKING_MAX_SUPPLY = 11_000_000e18;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address public constant SY_ADMIN = 0x8478F8c1d693aB4C054d3BBC0aBff4178b8F1b0B;

    address public constant USDC = 0xa51c9123a01e0d9fb1d55bA478e09f89f3D5Aebd;
    address public constant PROTOCOL_MULTISIG = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;

    address public OldPresale = address(0xCc3a494596d3160DAfAD3C25aF29B4327aBBAf3C);
    address public OldStaking = address(0x1000c5612932b9B9A1abf8A06Ef3d3220DBaa940);

    SafeToken public safeToken = SafeToken(0xD08B28Ad99e88e7cAC99F2aa61aaf6Ad3D2421a6);
    SafeYieldRewardDistributor public distributor =
        SafeYieldRewardDistributor(0x225b3fB1C83fC7ab218a5a172137d3cFdf6aACf0);

    SafeYieldPresale public presale;
    SafeYieldStaking public staking;

    uint128 minAllocationPerWallet = 1e18;
    uint128 maxAllocationPerWallet = PRE_SALE_MAX_SUPPLY;
    uint128 tokenPrice = 8e17; //e.g 0.8 usdc
    uint128 referrerCommissionUsdcBps = 500; //5% => 500 bps
    uint128 referrerCommissionSafeTokenBps = 500; // 5% => 500 bps

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK_DL");
        vm.startBroadcast(deployerPrivateKey);

        SafeYieldPresale oldPresaleContract = SafeYieldPresale(OldPresale);

        oldPresaleContract.pause();

        staking = new SafeYieldStaking(address(safeToken), USDC);

        presale = new SafeYieldPresale(
            address(safeToken),
            USDC,
            address(staking),
            minAllocationPerWallet,
            maxAllocationPerWallet,
            tokenPrice,
            referrerCommissionUsdcBps,
            referrerCommissionSafeTokenBps,
            SY_ADMIN
        );

        safeToken.grantRole(BURNER_ROLE, SY_ADMIN);

        uint256 oldPresaleBal = safeToken.balanceOf(OldPresale);
        uint256 oldStakingBal = safeToken.balanceOf(OldStaking);

        //burn presale say tokens
        safeToken.burn(OldPresale, oldPresaleBal);

        //burn staking say tokens
        safeToken.burn(OldStaking, oldStakingBal);

        //set new allocation
        safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        presale.mintPreSaleAllocation();

        //update new staking
        distributor.updateSafeStaking(address(staking));

        vm.stopBroadcast();

        _validConfigs();

        _logAddresses();
    }

    function _logAddresses() internal view {
        console.log("New Staking Contract ", address(staking));
        console.log("New Presale Contract", address(presale));
    }

    function _validConfigs() internal view {
        require(
            safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY,
            "New PreSale should be equal to PRE_SALE_MAX_SUPPLY"
        );
        require(safeToken.balanceOf(OldPresale) == 0, "Old Presale balance should be Zero");
        require(safeToken.balanceOf(OldStaking) == 0, "Old Staking balance should be Zero");

        ContractShare[] memory allContracts = distributor.getAllContracts();

        ContractShare memory newStakingContract = allContracts[1];

        require(newStakingContract.contract_ == address(staking), "New Staking should be Equal");
        require(newStakingContract.share == 6_000);
    }
}
