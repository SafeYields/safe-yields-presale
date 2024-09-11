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

    address public constant SY_ADMIN = 0x3e88e60894D081B27D180fcADd524365A3DE7Dd4;

    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant PROTOCOL_MULTISIG = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;

    address public OldPresale = address(0x5e6c54d4B60C6220a9ad8C49Cd802b958CA2672D);
    address public OldStaking = address(0x4E82e319CFCaD06DC82da04CBa03f1e9233f806b);

    SafeToken public safeToken = SafeToken(0x19D4b337B77b04256668679159E0b78A42fb0a1a);
    SafeYieldRewardDistributor public distributor =
        SafeYieldRewardDistributor(0xb0078df6b45eaa683b5DFD032D35fF2925e5690e);

    SafeYieldPresale public presale;
    SafeYieldStaking public staking;

    uint128 minAllocationPerWallet = 1e18;
    uint128 maxAllocationPerWallet = PRE_SALE_MAX_SUPPLY;
    uint128 tokenPrice = 8e17; //e.g 0.8 usdc
    uint128 referrerCommissionUsdcBps = 500; //5% => 500 bps
    uint128 referrerCommissionSafeTokenBps = 500; // 5% => 500 bps

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
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
            PROTOCOL_MULTISIG
        );

        safeToken.grantRole(BURNER_ROLE, SY_ADMIN);

        uint256 oldPresaleBal = safeToken.balanceOf(OldPresale);
        uint256 oldStakingBal = safeToken.balanceOf(OldStaking);

        //burn presale say tokens
        safeToken.burn(OldPresale, oldPresaleBal);

        //burn staking say tokens
        safeToken.burn(OldStaking, oldStakingBal);

        //renounce the burner role
        safeToken.renounceRole(BURNER_ROLE, SY_ADMIN);

        //set new allocation
        safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        presale.mintPreSaleAllocation();

        //update new staking
        distributor.updateSafeStaking(address(staking));

        staking.setPresale(address(presale));
        staking.setRewardDistributor(address(distributor));

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
