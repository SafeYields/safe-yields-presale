// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { console } from "forge-std/Test.sol";

contract SafeYieldTWAPTest is SafeYieldBaseTest {
    function testTWAP() public view {
        console.log("Price of WETH", twap.getEstimateAmountOut(UNISWAP_V3_POOL, WETH, 1e18, 3600));
    }
}
