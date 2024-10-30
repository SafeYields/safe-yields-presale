// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldTradingBaseTest } from "../setup/SafeYieldTradingBaseTest.t.sol";
import { SafeYieldBaseTest } from "../setup/SafeYieldBaseTest.t.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console } from "forge-std/Test.sol";
import { IVault, OrderType } from "./IVault.sol";

contract VelaHandlerTest is SafeYieldBaseTest {
// address public USDC_WHALE_ARB = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;
// // address public USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

// function transferUSDC(address user, uint256 amount) public {
//     vm.prank(USDC_WHALE_ARB);
//     IERC20(USDC_ARB).transfer(user, amount);
// }

// function testUSDCTransferred() public {
//     transferUSDC(ALICE, 1_000e6);
// }

// function testVelaVault() public {
//     transferUSDC(address(velaHandler), 1_000e6);

//     uint256[] memory params = new uint256[](4);
//     params[0] = 168331567680524983643408631905913;
//     params[1] = 250;
//     params[2] = 50000000000000000000000000000000;
//     params[3] = 1325000000000000000000000000000000;

//     vm.deal(address(velaHandler), 20 ether);

//     bytes memory data = abi.encodeWithSignature(
//         "newPositionOrder(uint256,bool,uint8,uint256[],address)", 8, true, OrderType.MARKET, params, address(0)
//     );
//     bytes memory handlerData = abi.encode("NewData");

//     vm.startPrank(address(velaHandler));
//     IERC20(USDC_ARB).approve(address(VELA_VAULT), 1_000e6);
//     IVault(VELA_VAULT).deposit(address(velaHandler), USDC_ARB, 1_000e6);

//     velaHandler.openStrategy{ value: 10 ether }(handlerData, data);
// }
}
