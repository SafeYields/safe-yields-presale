// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

//import { SafeYieldBaseTest } from "./SafeYieldBaseTest.t.sol";
import { VaultStrategy } from "src/trading/VaultStrat.sol";
//import { UsdcToken } from "src/trading/UsdcToken.sol";
import { console, console2, Test } from "forge-std/Test.sol";

contract VaultStratsTest is Test {
    VaultStrategy vs;

    address public ALICE = makeAddr("ALICE");
    address public BOB = makeAddr("BOB");
    address public CHARLIE = makeAddr("CHARLIE");
    address public ADMIN = makeAddr("ADMIN");

    function setUp() public {
        vs = new VaultStrategy();
    }

    function testMultipleDepositsMultipleOps() public {
        skip(block.timestamp + 5 minutes);

        vm.startPrank(ALICE);
        vs.deposit(1_000e18);
        vm.stopPrank();
        console.log("ALICE Deposited 1_000e18 at timestamp", block.timestamp);

        skip(block.timestamp + 5 minutes);

        //alice share Utilized : 333.33
        //unutilized : 666

        //Bob Deposits
        vm.startPrank(BOB);
        vs.deposit(2_000e18);
        console.log("BOB Deposited 2_000e18 at timestamp", block.timestamp);
        vm.stopPrank();

        //bob share utilized : 666.66
        //bob unutilized : 1333.33
        console.log();
        skip(block.timestamp + 5 minutes);

        //alice share Utilized : 333.33
        //bob share utilized : 666.66
        console.log("Strategy 1 Executed With 1_000e18 at timestamp", block.timestamp);
        vs.executeTrade(1_000e18);

        skip(block.timestamp + 5 minutes);

        //alice deposit : 1_000
        console.log();
        console.log("Alice Depositing 1_000e18 again at timestamp", block.timestamp);
        vm.prank(ALICE);
        vs.deposit(1_000e18);
        console.log();

        skip(block.timestamp + 5 minutes);

        //charlie deposits
        vm.startPrank(CHARLIE);
        vs.deposit(2_000e18);
        console.log("CHARLIE Deposited at 2_000e18 timestamp", block.timestamp);
        vm.stopPrank();

        skip(block.timestamp + 5 minutes);
        console.log();

        //alice utilized for trade 2 : 83.25
        //bob utilized for trade 2; 166
        //charlie utilized for trade : 250
        console.log("Strategy 2 Executed With 500e18 at timestamp", block.timestamp);
        vs.executeTrade(500e18);

        skip(block.timestamp + 5 minutes);

        //alice utilized for trade 3: 166.57
        //bob utilized for trade 3 : 333
        //charlie utilized for trade 3 : 500
        console.log("Strategy 3 Executed With 1_000e18 at timestamp", block.timestamp);
        vs.executeTrade(1_000e18);

        skip(block.timestamp + 5 minutes);

        console.log();

        //End Trade
        console.log("Strategy 1 Makes 1_000e18 Profit");
        vs.endTrade(0, 1_000e18);
        //Alice gets 333 as PNL for trade 1
        //Bob gets 666 as PNL for trade 1

        skip(block.timestamp + 5 minutes);

        //end trade
        console.log("Strategy 2 Makes 1_000e18 Profit");
        vs.endTrade(1, 1000e18);
        //Alice gets 166.5 as PNL for trade 2
        //Bob gets 332 as PNL for trade 2
        //Charlie gets 500 a PNL for trade 2

        //pending rewards
        skip(block.timestamp + 5 minutes);

        console.log("Strategy 3 Makes -500e18 Loss");
        vs.endTrade(2, -500e18);
        //Alice gets -83.29 as PNL for trade 3
        //Bob gets -166.5 as PNL for trade 3
        //Charlie gets -250 a PNL for trade 3
        console.log();
        vm.prank(ALICE);
        console.log("******************* ALICE Should claim for All 3 Strategies ****************");
        //console2.log("ALICE Pending PNL", vs.getPNL(ALICE));
        int256 alicePnl = vs.claimPnl();

        vm.prank(BOB);
        console.log("******************* BOB should claim for All 3 Strategies ****************");
        //console2.log("BOB Pending PNL", vs.getPNL(BOB));
        int256 bobPnl = vs.claimPnl();

        vm.prank(CHARLIE);
        console.log("******************* CHARLIE should should claim for only Strategy 2 an 3 ****************");
        //console2.log("CHARLIE Pending PNL", vs.getPNL(CHARLIE));
        int256 charliePnl = vs.claimPnl();

        console.log("Total PNL for 3 Strategies 1_500e18 Profit");
        console.log();
        console2.log("Alice PNL", alicePnl);
        console2.log("Bob PNL", bobPnl);
        console2.log("Charlie PNL", charliePnl);
    }
}
