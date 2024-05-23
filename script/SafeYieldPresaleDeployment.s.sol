// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { sSafeToken } from "src/sSafeToken.sol";
import { SafeToken } from "src/SafeToken.sol";
import { USDCMockToken } from "test/mocks/USDCMockToken.sol";

contract SafeYieldPresaleDeployment is Script {
    uint256 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;

    address public constant SAFE_YIELD_ADMIN = 0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF;
    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeToken public safe;
    sSafeToken public sSafe;
    USDCMockToken usdc;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        usdc = new USDCMockToken("USDC", "USDC", 6);
        safe = new SafeToken("SafeToken", "SAFE", SAFE_YIELD_ADMIN);
        sSafe = new sSafeToken("sSafeToken", "sSAFE", SAFE_YIELD_ADMIN);

        staking = new SafeYieldStaking(address(safe), address(sSafe), address(usdc), SAFE_YIELD_ADMIN);

        presale = new SafeYieldPresale(
            address(safe),
            address(sSafe),
            address(usdc),
            address(staking),
            1_000e18,
            100_000e18,
            1e18,
            5_00,
            5_00,
            SAFE_YIELD_ADMIN
        );

        vm.stopBroadcast();

        //configurations
        vm.startBroadcast(deployerPrivateKey);
        safe.grantRole(safe.MINTER_ROLE(), address(presale));

        sSafe.grantRole(sSafe.MINTER_ROLE(), address(staking));

        safe.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        presale.startPresale();

        _mintUsdc2Admin();

        vm.stopBroadcast();

        logAddresses();
    }

    function logAddresses() public view {
        console.log("USDC", address(usdc));
        console.log("Safe Token", address(safe));
        console.log("sSafe Tokens", address(sSafe));
        console.log("Staking", address(staking));
        console.log("Presale", address(presale));
    }

    function _mintUsdc2Admin() internal {
        usdc.mint(SAFE_YIELD_ADMIN, 100_000e6);
    }

    /**
     * forge script script/SafeYieldPresaleDeployment.so.sol --rpc-url sepolia --etherscan-api-key sepolia -vv
     */
}
