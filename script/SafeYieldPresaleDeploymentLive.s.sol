// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { SafeToken } from "src/SafeToken.sol";
import { SafeYieldTWAP } from "src/SafeYieldTWAP.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";

contract SafeYieldPresaleDeployment is Script {
    uint256 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint256 public constant STAKING_MAX_SUPPLY = 11_000_000e18;

    //The addresses here need to be changed
    address public constant SY_ADMIN = 0x8478F8c1d693aB4C054d3BBC0aBff4178b8F1b0B; //!CHANGE
    address public constant teamOperations = address(0x8478F8c1d693aB4C054d3BBC0aBff4178b8F1b0B); //!CHANGE
    address public constant usdcBuyback = address(0x8478F8c1d693aB4C054d3BBC0aBff4178b8F1b0B); //!CHANGE
    
    address public constant usdcAddressAbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; //!Verify
    //https://arbiscan.io/token/0xaf88d065e77c8cC2239327C5EDb3A432268e5831

    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeYieldRewardDistributor public distributor;
    SafeToken public safeToken;
    SafeYieldTWAP twap;

    
    uint128 minAllocationPerWallet = 5e18;
    uint128 maxAllocationPerWallet = uint128(PRE_SALE_MAX_SUPPLY); //set max allocation per wallet to the presale max supply
    uint128 tokenPrice = 1e18; //e.g 1 usdc
    uint128 referrerCommissionUsdcBps = 5_00; //5% => 500 bps
    uint128 referrerCommissionSafeTokenBps = 5_00; // 5% => 500 bps
    address protcolMultisig = SY_ADMIN;

    /**
     * @dev Run the script to deploy contracts to Arbitrum One
     * @dev replace "ARBITRUM_SCAN_API_KEY" with your arbiscan api key
     * forge script script/SafeYieldPresaleDeploymentLive.s.sol --rpc-url https://rpc.ankr.com/arbitrum	 --etherscan-api-key "ARBITRUM_SCAN_API_KEY" --verify --vv
     */
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        safeToken = new SafeToken(); //deploy new safe token

        staking = new SafeYieldStaking(address(safeToken), usdcAddressAbitrum); // deploy new staking contract

        presale = new SafeYieldPresale(
            address(safeToken),
            usdcAddressAbitrum,
            address(staking),
            minAllocationPerWallet,
            maxAllocationPerWallet,
            tokenPrice,
            referrerCommissionUsdcBps,
            referrerCommissionSafeTokenBps,
            protcolMultisig
        );

        twap = new SafeYieldTWAP();

        distributor = new SafeYieldRewardDistributor(
            address(safeToken), usdcAddressAbitrum, teamOperations, usdcBuyback, address(staking), address(twap)
        );

        vm.stopBroadcast();

        //configurations
        vm.startBroadcast(deployerPrivateKey);
        //set allocation limits
        safeToken.setAllocationLimit(address(distributor), STAKING_MAX_SUPPLY);
        safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        staking.setPresale(address(presale));
        staking.setRewardDistributor(address(distributor));

        //mint allocations
        presale.mintPreSaleAllocation();
        distributor.mintStakingEmissionAllocation();

        vm.stopBroadcast();

        validateConfigs();

        logAddresses();
    }

    function logAddresses() public view {
        console.log("USDC", usdcAddressAbitrum);
        console.log("Safe Token", address(safeToken));
        console.log("Staking", address(staking));
        console.log("Presale", address(presale));
        console.log("TWAP", address(twap));
        console.log("Distributor", address(distributor));
    }

    function validateConfigs() internal view {
        //validate presale configuration
        require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
        require(address(presale.safeYieldStaking()) == address(staking), "Invalid staking address");
        require(address(presale.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(presale.usdcToken()) == usdcAddressAbitrum, "Invalid usdc address");
        require(presale.minAllocationPerWallet() == minAllocationPerWallet, "Invalid min allocation per wallet");
        require(presale.maxAllocationPerWallet() == maxAllocationPerWallet, "Invalid max allocation per wallet");
        require(presale.referrerCommissionSafeTokenBps() == referrerCommissionSafeTokenBps, "Invalid referrer commission safeToken token bps");
        require(presale.referrerCommissionUsdcBps() == referrerCommissionUsdcBps, "Invalid referrer commission usdc bps");

        //validate staking configuration
        require(address(staking.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(staking.usdc()) == usdcAddressAbitrum, "Invalid usdc address");
        require(address(staking.distributor()) == address(distributor), "Invalid distributor address");
        require(address(staking.presale()) == address(presale), "Invalid presale address");

        //validate distributor configuration
        require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
        require(address(distributor.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(distributor.usdcToken()) == usdcAddressAbitrum, "Invalid usdc address");
        require(address(distributor.safeYieldTWAP()) == address(twap), "Invalid twap address");
        require(distributor.teamOperations() == teamOperations, "Invalid team operations address");
        require(distributor.usdcBuyback() == usdcBuyback, "Invalid usdc buyback address");
        require(distributor.safeStaking() == address(staking), "Invalid staking address");
    }
}
