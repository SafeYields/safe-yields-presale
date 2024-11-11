// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { StrategyController } from "src/trading/StrategyController.sol";
import { StrategyFundManager } from "src/trading/StrategyFundManager.sol";
import { SafeYieldBaseTest } from "../setup/SafeYieldBaseTest.t.sol";
import { GMXHandler } from "src/trading/handlers/gmx/GMXHandler.sol";
import { VelaHandler } from "src/trading/handlers/vela/VelaHandler.sol";
import { ArbSysMock } from "../mocks/ArbSysMock.sol";
import { IRoleStore } from "test/trading/IRoleStore.sol";
import { IOrderHandler } from "src/trading/handlers/gmx/interfaces/IOrderHandler.sol";
import { Test, console } from "forge-std/Test.sol";

contract SafeYieldTradingBaseTest is Test {
    ArbSysMock public arbSysMock;
    uint256 public arbitrumFork;
    address public ALICE = makeAddr("alice");
    address public protocolAdmin = makeAddr("protocolAdmin");
    address public SAY_TRADER = makeAddr("sayTrader");
    address public VELA_VAULT = 0xC4ABADE3a15064F9E3596943c699032748b13352;
    address public USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public GMX__EXCHANGE_ROUTER = 0x69C527fC77291722b52649E45c838e41be8Bf5d5;
    address public GMX__ORDER_VAULT = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address public GMX__DATA_STORE = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address public GMX__READER = 0x23D4Da5C7C6902D4C86d551CaE60d5755820df9E;
    address public GMX__DEPLOYER = 0xE7BfFf2aB721264887230037940490351700a068;

    IRoleStore roleStore = IRoleStore(0x3c3d99FD298f679DBC2CEcd132b4eC4d0F5e6e72);
    IOrderHandler orderHandler = IOrderHandler(0xB0Fc2a48b873da40e7bc25658e5E6137616AC2Ee);

    GMXHandler gmxHandler;
    VelaHandler velaHandler;
    StrategyFundManager fundManager;
    StrategyController controller;

    function setUp() public {
        arbitrumFork = vm.createFork("arbitrum_rpc");

        vm.selectFork(arbitrumFork);

        vm.startPrank(protocolAdmin);

        arbSysMock = new ArbSysMock();
        vm.etch(address(0x0000000000000000000000000000000000000064), address(arbSysMock).code);

        fundManager = new StrategyFundManager(address(USDC_ARB), protocolAdmin);

        controller = new StrategyController(address(USDC_ARB), address(fundManager), protocolAdmin, SAY_TRADER);

        velaHandler = new VelaHandler(VELA_VAULT, USDC_ARB, address(controller), address(fundManager), "VELA_EXCHANGE");

        gmxHandler = new GMXHandler(
            GMX__EXCHANGE_ROUTER,
            USDC_ARB,
            address(controller),
            address(fundManager),
            GMX__READER,
            GMX__ORDER_VAULT,
            GMX__DATA_STORE,
            "GMX"
        );

        fundManager.setStrategyController(address(controller));

        vm.stopPrank();
    }
}
