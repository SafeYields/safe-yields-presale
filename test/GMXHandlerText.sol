// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { console } from "forge-std/Test.sol";

contract GMXHandlerTest is SafeYieldBaseTest {
    function testGMXKey() public view {
        // address account = 0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF;
        // address market = 0x47c031236e19d024b42f8AE6780E44A573170703;
        // address collateralToken = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        // bytes32 key = gmxHandler.getGMXPositionKey(account, market, collateralToken, true);

        // console.logBytes32(key);
    }
}
