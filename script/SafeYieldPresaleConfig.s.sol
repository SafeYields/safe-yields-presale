// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {SafeYieldStaking} from "src/SafeYieldStaking.sol";
import {sSafeToken} from "src/sSafeToken.sol";
import {SafeToken} from "src/SafeToken.sol";
import {USDCMockToken} from "test/mocks/USDCMockToken.sol";

contract SafeYieldPresaleConfig is Script {
    sSafeToken public sSafe =
        sSafeToken(0x571EBb6E71D3AdE60Bc25c15B9A0DA29abfDC06a);

    address public constant SAFE_YIELD_ADMIN =
        0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF;
    SafeYieldStaking public staking =
        SafeYieldStaking(0xaD97E7a67c82Ae79324B0D31775fa3335D8C404A);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        sSafe.grantRole(sSafe.MINTER_ROLE(), address(staking));
        vm.stopBroadcast();
    }
}
