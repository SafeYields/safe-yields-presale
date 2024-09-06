// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { SafeToken } from "src/SafeToken.sol";
import { SafeYieldTWAP } from "src/SafeYieldTWAP.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SafeYieldPresaleDeploymentPatch4 is Script {
    uint128 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint128 public constant STAKING_MAX_SUPPLY = 11_000_000e18;

    address public constant SAFE_YIELD_DEPLOYER = 0x3e88e60894D081B27D180fcADd524365A3DE7Dd4;

    address public constant SY_ADMIN = 0x3e88e60894D081B27D180fcADd524365A3DE7Dd4;
    address public constant TEAM_OPERATIONS = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;
    address public constant USDC_BUY_BACK = TEAM_OPERATIONS;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant PROTOCOL_MULTISIG = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;

    address public constant OLD_PRESALE = 0x63Aa64bB6dEA0FeE2C6A7503EA950Ce39D5BBE7C;
    address public constant OLD_RD = 0xb0078df6b45eaa683b5DFD032D35fF2925e5690e;
    address public constant OLD_TWAP = 0xD73F2f2560998cBcC53D223bf8A4b9f4c95104cA;
    address public constant OLD_STAKING = 0x184F397A215c9458264D5b2498f86eD7b048AA36;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeYieldRewardDistributor public distributor;
    SafeToken public safeToken = SafeToken(0x19D4b337B77b04256668679159E0b78A42fb0a1a);
    //SafeYieldTWAP twap;

    uint128 minAllocationPerWallet = 1e18;
    uint128 maxAllocationPerWallet = PRE_SALE_MAX_SUPPLY;
    uint128 tokenPrice = 8e17; //e.g 0.8 usdc
    uint128 referrerCommissionUsdcBps = 500; //5% => 500 bps
    uint128 referrerCommissionSafeTokenBps = 500; // 5% => 500 bps

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        staking = new SafeYieldStaking(address(safeToken), USDC); // deploy new staking contract

        presale = new SafeYieldPresale(
            address(safeToken),
            USDC,
            address(staking),
            address(0x1), //!note change to lockUp
            minAllocationPerWallet,
            maxAllocationPerWallet,
            tokenPrice,
            referrerCommissionUsdcBps,
            referrerCommissionSafeTokenBps,
            PROTOCOL_MULTISIG
        );

        distributor = new SafeYieldRewardDistributor(
            address(safeToken), USDC, TEAM_OPERATIONS, USDC_BUY_BACK, address(staking), OLD_TWAP
        );

        ///@dev deployment complete, start configurations

        ///
        safeToken.grantRole(BURNER_ROLE, SY_ADMIN);

        uint256 oldPresaleBal = safeToken.balanceOf(OLD_PRESALE);
        uint256 oldStakingBal = safeToken.balanceOf(OLD_STAKING);
        uint256 oldRdBal = safeToken.balanceOf(OLD_RD);

        //burn presale say tokens
        safeToken.burn(OLD_PRESALE, oldPresaleBal);
        safeToken.burn(OLD_STAKING, oldStakingBal);
        safeToken.burn(OLD_RD, oldRdBal);

        //renounce the burner role
        safeToken.renounceRole(BURNER_ROLE, SY_ADMIN);

        ///@dev pause all old contracts
        SafeYieldStaking(OLD_STAKING).pause();
        ///@dev presale already paused
        ///
        //set allocation limits
        safeToken.setAllocationLimit(address(distributor), STAKING_MAX_SUPPLY);
        safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        staking.setPresale(address(presale));
        staking.setRewardDistributor(address(distributor));

        //mint allocations
        presale.mintPreSaleAllocation();
        distributor.mintStakingEmissionAllocation();

        presale.startPresale();

        vm.stopBroadcast();

        _validateConfigs();

        _logAddresses();
    }

    function _logAddresses() internal view {
        console.log("USDC", USDC);
        console.log("Safe Token", address(safeToken));
        console.log("Staking", address(staking));
        console.log("Presale", address(presale));
        //console.log("TWAP", address(twap));
        console.log("Distributor", address(distributor));
    }

    function _validateConfigs() internal view {
        //validate presale configuration
        require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
        require(address(presale.safeYieldStaking()) == address(staking), "Invalid staking address");
        require(address(presale.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(presale.usdcToken()) == USDC, "Invalid usdc address");
        require(presale.minAllocationPerWallet() == minAllocationPerWallet, "Invalid min allocation per wallet");
        require(presale.maxAllocationPerWallet() == maxAllocationPerWallet, "Invalid max allocation per wallet");
        require(
            presale.referrerCommissionSafeTokenBps() == referrerCommissionSafeTokenBps,
            "Invalid referrer commission safeToken token bps"
        );
        require(
            presale.referrerCommissionUsdcBps() == referrerCommissionUsdcBps, "Invalid referrer commission usdc bps"
        );

        //validate staking configuration
        require(address(staking.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(staking.usdc()) == USDC, "Invalid usdc address");
        require(address(staking.distributor()) == address(distributor), "Invalid distributor address");
        require(address(staking.presale()) == address(presale), "Invalid presale address");

        //validate distributor configuration
        require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
        require(address(distributor.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(distributor.usdcToken()) == USDC, "Invalid usdc address");
        require(address(distributor.safeYieldTWAP()) == OLD_TWAP, "Invalid twap address");
        require(distributor.teamOperations() == TEAM_OPERATIONS, "Invalid team operations address");
        require(distributor.usdcBuyback() == USDC_BUY_BACK, "Invalid usdc buyback address");
        require(distributor.safeStaking() == address(staking), "Invalid staking address");
    }
}
