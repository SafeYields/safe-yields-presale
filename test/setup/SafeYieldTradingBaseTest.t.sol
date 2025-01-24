// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { StrategyController } from "src/trading/StrategyController.sol";
import { StrategyFundManager } from "src/trading/StrategyFundManager.sol";
import { SafeYieldBaseTest } from "../setup/SafeYieldBaseTest.t.sol";
import { GMXHandler } from "src/trading/handlers/gmx/GMXHandler.sol";
import { VelaHandler } from "src/trading/handlers/vela/VelaHandler.sol";
import { ArbSysMock } from "../mocks/ArbSysMock.sol";
import { IRoleStore } from "test/trading/IRoleStore.sol";
import { IExchangeRouter } from "src/trading/handlers/gmx/interfaces/IExchangeRouter.sol";

//import { IOrderHandler } from "src/trading/handlers/gmx/interfaces/IOrderHandler.sol";
import { Test, console } from "forge-std/Test.sol";
import { OrderHandler, IOrderHandler } from "test/gmx2/contracts/exchange/OrderHandler.sol";
import { IReferralStorage } from "test/gmx2/contracts/referral/IReferralStorage.sol";
import { RoleStore } from "test/gmx2/contracts/role/RoleStore.sol";
import { EventEmitter } from "test/gmx2/contracts/event/EventEmitter.sol";
import { Oracle } from "test/gmx2/contracts/oracle/Oracle.sol";
import { OrderVault } from "test/gmx2/contracts/order/OrderVault.sol";
import { SwapHandler } from "test/gmx2/contracts/swap/SwapHandler.sol";
import { DataStore } from "test/gmx2/contracts/data/DataStore.sol";
import { IDepositHandler } from "test/gmx2/contracts/exchange/IDepositHandler.sol";
import { IWithdrawalHandler } from "test/gmx2/contracts/exchange/IWithdrawalHandler.sol";
import { IShiftHandler } from "test/gmx2/contracts/exchange/IShiftHandler.sol";
import { Router } from "test/gmx2/contracts/router/Router.sol";
import { IExternalHandler } from "test/gmx2/contracts/external/IExternalHandler.sol";
import { FeeManager } from "../mocks/gmx/FeeManager.sol";
import { IReader } from "src/trading/handlers/gmx/interfaces/IReader.sol";

contract SafeYieldTradingBaseTest is Test {
    ArbSysMock public arbSysMock;
    uint256 public arbitrumFork;
    address public ALICE = makeAddr("alice");
    address public protocolAdmin = makeAddr("protocolAdmin");
    address public SAY_TRADER = makeAddr("sayTrader");
    address public VELA_VAULT = 0xC4ABADE3a15064F9E3596943c699032748b13352;
    address public USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public GMX__EXCHANGE_ROUTER = 0x900173A66dbD345006C51fA35fA3aB760FcD843b;
    address public GMX__ORDER_VAULT = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address public GMX__DATA_STORE = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address public GMX__READER = 0x0537C767cDAC0726c76Bb89e92904fe28fd02fE1;
    address public GMX__DEPLOYER = 0xE7BfFf2aB721264887230037940490351700a068;

    RoleStore roleStore = RoleStore(0x3c3d99FD298f679DBC2CEcd132b4eC4d0F5e6e72);
    DataStore dataStore = DataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);
    EventEmitter eventEmitter = EventEmitter(0xC8ee91A54287DB53897056e12D9819156D3822Fb);
    Oracle oracle = Oracle(0xb8fc96d7a413C462F611A7aC0C912c2FE26EAbC4);
    OrderVault orderVault = OrderVault(payable(0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5));
    SwapHandler swapHandler = SwapHandler(0x9CbB37630d65324af064F28CCD9dF6E667Cb16F1);
    IReferralStorage refStorage = IReferralStorage(0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d);
    Router router = Router(0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6);
    IDepositHandler depositHandler = IDepositHandler(0x321f3739983CC3E911fd67a83d1ee76238894Bd0);
    IWithdrawalHandler withdrawalHandler = IWithdrawalHandler(0xA19fA3F0D8E7b7A8963420De504b624167e709B2);
    IShiftHandler shiftHandler = IShiftHandler(0xEa90EC1228F7D1b3D47D84d1c9D46dBDFEfF7709);
    IExternalHandler externalHandler = IExternalHandler(0x389CEf541397e872dC04421f166B5Bc2E0b374a5);
    IReader reader = IReader(0x0537C767cDAC0726c76Bb89e92904fe28fd02fE1);

    IOrderHandler iOrderHandler = IOrderHandler(0xe68CAAACdf6439628DFD2fe624847602991A31eB);

    GMXHandler gmxHandler;
    VelaHandler velaHandler;
    StrategyFundManager fundManager;
    StrategyController controller;

    OrderHandler public orderHandler;

    IExchangeRouter exchangeRouter;

    function setUp() public {
        arbitrumFork = vm.createFork("arbitrum_rpc");

        vm.selectFork(arbitrumFork);

        orderHandler = new OrderHandler(roleStore, dataStore, eventEmitter, oracle, orderVault, swapHandler, refStorage);

        vm.etch(address(0xe68CAAACdf6439628DFD2fe624847602991A31eB), address(orderHandler).code);

        arbSysMock = new ArbSysMock();
        vm.etch(address(0x0000000000000000000000000000000000000064), address(arbSysMock).code);

        FeeManager feeManager = new FeeManager(
            0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            0x478Aa2aC9F6D65F84e09D9185d126c3a17c2a93C,
            0x525a8B8E83A8168c599F6160f6303002C19087A9
        );

        vm.etch(address(0x5ad1d6Ad0140243a7F924e7071bAe4949F1ad5f8), address(feeManager).code);

        vm.startPrank(protocolAdmin);

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

        exchangeRouter = IExchangeRouter(GMX__EXCHANGE_ROUTER);

        vm.stopPrank();
    }
}
