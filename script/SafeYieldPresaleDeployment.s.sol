// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { SafeToken } from "src/SafeToken.sol";
import { SafeYieldTWAP } from "src/SafeYieldTWAP.sol";
import { USDCMockToken } from "test/mocks/USDCMockToken.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";

contract SafeYieldPresaleDeployment is Script {
    uint256 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint256 public constant STAKING_MAX_SUPPLY = 11_000_000e18;
    address public constant SAFE_YIELD_ADMIN = 0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF; //!CHANGE
    address public constant teamOperations = address(0x14); //!CHANGE
    address public constant usdcBuyback = address(0x15); //!CHANGE
    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeYieldRewardDistributor public distributor;
    SafeToken public safeToken;
    USDCMockToken usdc;
    SafeYieldTWAP twap;

    /**
     * @dev Run the script
     * forge script script/SafeYieldPresaleDeployment.so.sol --rpc-url sepolia --etherscan-api-key sepolia --verify --vv
     */
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        usdc = new USDCMockToken("USDC", "USDC", 6);

        safeToken = new SafeToken();

        staking = new SafeYieldStaking(address(safeToken), address(usdc));

        presale = new SafeYieldPresale(
            address(safeToken),
            address(usdc),
            address(staking),
            1_000e18,
            100_000e18,
            1e18,
            5_00,
            5_00,
            SAFE_YIELD_ADMIN
        );

        twap = new SafeYieldTWAP();

        distributor = new SafeYieldRewardDistributor(
            address(safeToken), address(usdc), teamOperations, usdcBuyback, address(staking), address(twap)
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
        console.log("USDC", address(usdc));
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
        require(address(presale.usdcToken()) == address(usdc), "Invalid usdc address");
        require(presale.minAllocationPerWallet() == 1_000e18, "Invalid min allocation per wallet");
        require(presale.maxAllocationPerWallet() == 100_000e18, "Invalid max allocation per wallet");
        require(presale.referrerCommissionSafeTokenBps() == 5_00, "Invalid referrer commission safeToken token bps");
        require(presale.referrerCommissionUsdcBps() == 5_00, "Invalid referrer commission usdc bps");

        //validate staking configuration
        require(address(staking.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(staking.usdc()) == address(usdc), "Invalid usdc address");
        require(address(staking.distributor()) == address(distributor), "Invalid distributor address");
        require(address(staking.presale()) == address(presale), "Invalid presale address");

        //validate distributor configuration
        require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
        require(address(distributor.safeToken()) == address(safeToken), "Invalid safeToken token address");
        require(address(distributor.usdcToken()) == address(usdc), "Invalid usdc address");
        require(address(distributor.safeYieldTWAP()) == address(twap), "Invalid twap address");
        require(distributor.teamOperations() == teamOperations, "Invalid team operations address");
        require(distributor.usdcBuyback() == usdcBuyback, "Invalid usdc buyback address");
        require(distributor.safeStaking() == address(staking), "Invalid staking address");
    }
}
