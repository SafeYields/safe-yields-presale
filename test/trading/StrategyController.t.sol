// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldTradingBaseTest } from "../setup/SafeYieldTradingBaseTest.t.sol";
import { console } from "forge-std/Test.sol";
import { IVault } from "test/trading/IVault.sol";
import { IRoleStore } from "test/trading/IRoleStore.sol";
import { IOrderVault } from "src/trading/handlers/vela/interfaces/IOrderVault.sol";
import { IExchangeRouter } from "src/trading/handlers/gmx/interfaces/IExchangeRouter.sol";
import { IReader } from "src/trading/handlers/gmx/interfaces/IReader.sol";
import { IDataStore } from "src/trading/handlers/gmx/interfaces/IDataStore.sol";
import { ExchangeRouter } from "test/gmx2/contracts/router/ExchangeRouter.sol";
import { IPositionVault } from "src/trading/handlers/vela/interfaces/IPositionVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { UserDepositDetails } from "src/trading/StrategyFundManager.sol";
import { OrderType } from "src/trading/types/StrategyControllerTypes.sol";
import { Order } from "src/trading/handlers/vela/types/VelaTypes.sol";
import { OracleUtils } from "test/gmx2/contracts/oracle/OracleUtils.sol";
import { PositionProps } from "src/trading/handlers/gmx/types/PositionTypes.sol";
import { OrderProps } from "src/trading/handlers/gmx/types/OrderTypes.sol";
import {
    CreateOrderParams,
    CreateDepositParams,
    CreateOrderParamsAddresses,
    DecreasePositionSwapType,
    GMXOrderType,
    SetPricesParams,
    CreateOrderParamsNumbers
} from "src/trading/handlers/gmx/types/GMXTypes.sol";
import { OrderHandler } from "test/gmx2/contracts/exchange/OrderHandler.sol";
import { Oracle } from "test/gmx2/contracts/oracle/Oracle.sol";
import { AggregatorV2V3Interface } from "test/gmx2/contracts/oracle/AggregatorV2V3Interface.sol";

import { IOrderHandler } from "src/trading/handlers/gmx/interfaces/IOrderHandler.sol";

contract StrategyControllerTest is SafeYieldTradingBaseTest {
    address public USDC_WHALE_ARB = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;
    address WETH_ARB = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address GMX__ETH_USD = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
    address public ORDER_KEEPER = 0xE47b36382DC50b90bCF6176Ddb159C4b9333A7AB;
    address public CHAIN_LNK_PROVIDER = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;
    Oracle oracleMock;

    function transferUSDC(address user, uint256 amount) public {
        vm.prank(USDC_WHALE_ARB);
        IERC20(USDC_ARB).transfer(user, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                  GMX
    //////////////////////////////////////////////////////////////*/

    function testUserDepositFundManager() public {
        transferUSDC(ALICE, 10_000e6);

        vm.startPrank(ALICE);

        IERC20(USDC_ARB).approve(address(fundManager), 10_000e6);
        fundManager.deposit(10_000e6);
        vm.stopPrank();
    }

    function testGMX__AddNewMarketIncreaseOrder() public returns (bytes32) {
        vm.roll(274428852);

        testUserDepositFundManager();

        vm.prank(protocolAdmin);
        controller.grantRole(keccak256("SAY_TRADER_ROLE"), 0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2);

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory params = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: 0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
                initialCollateralToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 209517740254460100375000000000000000,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 3947042505160081271952838,
                executionFee: 275023333689000,
                callbackGasLimit: 0,
                minOutputAmount: 0
            }),
            orderType: GMXOrderType.MarketIncrease, // Example: Market increase position
            decreasePositionSwapType: DecreasePositionSwapType.NoSwap, // Example: No swap
            isLong: true, // Example: Long position
            shouldUnwrapNativeToken: false, // Example: Do not unwrap native token
            autoCancel: false, // Example: Do not auto-cancel
            referralCode: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        bytes memory data2 = abi.encodeWithSelector(IExchangeRouter.createOrder.selector, params);

        vm.deal(address(gmxHandler), 10 ether);

        bytes32 orderKey = getOrderKey();

        vm.prank(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2);

        controller.openStrategy(
            address(gmxHandler),
            0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
            7727441812,
            275023333689000,
            true,
            OrderType.MARKET,
            data2
        );

        OrderProps memory order = reader.getOrder(address(dataStore), orderKey);

        assertEq(order.addresses.account, address(gmxHandler));
        assertEq(order.addresses.initialCollateralToken, USDC_ARB);
        assertEq(order.numbers.sizeDeltaUsd, 209517740254460100375000000000000000);

        //! assertions
        //! 1. fund manager
        //! 2. controller
        //! 3. balance difference

        return orderKey;
    }

    function testGMX__AddNewLimitIncreaseOrder() public returns (bytes32) {
        vm.roll(273449734);

        testUserDepositFundManager();

        vm.prank(protocolAdmin);
        controller.grantRole(keccak256("SAY_TRADER_ROLE"), 0xc8188185DC0895B39382c52659889BcDcb195e66);

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory params = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: 0xc8188185DC0895B39382c52659889BcDcb195e66,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x47c031236e19d024b42f8AE6780E44A573170703,
                initialCollateralToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 24917394238568732314750000000000000,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 860000000000000000000000000,
                acceptablePrice: 863268000000000000000000000,
                executionFee: 269195862000000,
                callbackGasLimit: 0,
                minOutputAmount: 0
            }),
            orderType: GMXOrderType.LimitIncrease, // Example: Market increase position
            decreasePositionSwapType: DecreasePositionSwapType.NoSwap, // Example: No swap
            isLong: true, // Example: Long position
            shouldUnwrapNativeToken: false, // Example: Do not unwrap native token
            autoCancel: false, // Example: Do not auto-cancel
            referralCode: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        bytes memory data2 = abi.encodeWithSelector(IExchangeRouter.createOrder.selector, params);

        vm.deal(address(gmxHandler), 10 ether);

        bytes32 orderKey = getOrderKey();

        vm.prank(0xc8188185DC0895B39382c52659889BcDcb195e66);

        controller.openStrategy(
            address(gmxHandler),
            0x47c031236e19d024b42f8AE6780E44A573170703,
            5000000000,
            269195862000000,
            true,
            OrderType.LIMIT,
            data2
        );

        OrderProps memory order = reader.getOrder(address(dataStore), orderKey);

        return orderKey;
    }

    function testGMX__UpdatePosition() public {
        testGMX__ExecuteOrder();

        vm.roll(394428852);

        console.log("ETH balance", (0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2).balance);
        console.log("USDC_BALANCE", IERC20(USDC_ARB).balanceOf(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2));

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory params = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: 0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
                initialCollateralToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 209517740254460100375000000000000000,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 3947042505160081271952838,
                executionFee: 275023333689000,
                callbackGasLimit: 0,
                minOutputAmount: 0
            }),
            orderType: GMXOrderType.MarketDecrease, // Example: Market increase position
            decreasePositionSwapType: DecreasePositionSwapType.NoSwap, // Example: No swap
            isLong: true, // Example: Long position
            shouldUnwrapNativeToken: false, // Example: Do not unwrap native token
            autoCancel: false, // Example: Do not auto-cancel
            referralCode: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        bytes memory data2 = abi.encodeWithSelector(exchangeRouter.createOrder.selector, params);

        bytes[] memory multicallData = new bytes[](3);

        //call exchangeRouter sendWNT tokens to pay fee.
        bytes memory sendExecutionFeeData = abi.encodeWithSelector(
            exchangeRouter.sendWnt.selector, 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5, 275023333689000
        );

        //send collateral
        bytes memory sendCollateralData = abi.encodeWithSelector(
            exchangeRouter.sendTokens.selector, USDC_ARB, 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5, 7727441812
        );

        multicallData[0] = sendExecutionFeeData;
        multicallData[1] = sendCollateralData;
        multicallData[2] = data2;

        bytes32 key = getOrderKey();

        transferUSDC(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2, 7727441812);

        vm.startPrank(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2);

        IERC20(USDC_ARB).approve(0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6, 7727441812);

        exchangeRouter.multicall{ value: 275023333689000 }(multicallData);
    }

    /**
     */
    function testGMX__ModifyOrder() public {
        bytes32 key = testGMX__AddNewLimitIncreaseOrder();

        bytes memory exchangeData = abi.encode(key, 0, 0, 840000000000000000000000000, 0, false);

        OrderProps memory orderPrior = reader.getOrder(address(dataStore), key);

        assertEq(orderPrior.numbers.triggerPrice, 860000000000000000000000000);

        vm.prank(0xc8188185DC0895B39382c52659889BcDcb195e66);
        controller.updateStrategy(address(gmxHandler), 1, 0, exchangeData);

        OrderProps memory updatedOrder = reader.getOrder(address(dataStore), key);

        assertEq(updatedOrder.numbers.triggerPrice, 840000000000000000000000000);
    }

    function testGMX__CancelOrder() public {
        bytes32 key = testGMX__AddNewMarketIncreaseOrder();

        bytes memory exchangeData = abi.encodeWithSelector(IExchangeRouter.cancelOrder.selector, key);

        skip(300);

        vm.prank(SAY_TRADER);
        controller.cancelStrategy(address(gmxHandler), exchangeData);

        assertEq(IERC20(USDC_ARB).balanceOf(address(gmxHandler)), 7727441812);
    }

    function testGMX__ExecuteOrder() public returns (bytes32) {
        bytes32 key = testGMX__AddNewMarketIncreaseOrder();

        vm.roll(274428861);

        vm.warp(1720979279);

        address[] memory tokens = new address[](2);
        address[] memory providers = new address[](2);
        bytes[] memory data = new bytes[](2);

        tokens[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        tokens[1] = 0xA1b91fe9FD52141Ff8cac388Ce3F10BFDc1dE79d;

        providers[0] = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;
        providers[1] = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;

        data[0] = vm.parseBytes(
            "0x00064c28ccf99cc505d648ffcbc4c2c613859826fd4552841a6822b51800d961000000000000000000000000000000000000000000000000000000001f291106000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000003000101000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd9920000000000000000000000000000000000000000000000000000000067361e710000000000000000000000000000000000000000000000000000000067361e7100000000000000000000000000000000000000000000000000005e970d62bb980000000000000000000000000000000000000000000000000057c1850fd2fb880000000000000000000000000000000000000000000000000000000067376ff10000000000000000000000000000000000000000000000000ddff7b537fce0000000000000000000000000000000000000000000000000000ddfda1f3ce4ac000000000000000000000000000000000000000000000000000de072f51b483a840000000000000000000000000000000000000000000000000000000000000006032be3c7fddb6061f2d795cf1b4baacfad71ac72be85b7ca2d09cad90716a07d067e959655a83bd4701a28c7dac284a1911a32d94ce75d5bfe8967e2d488b6222a5523f78e94f794cc4d20ab43602c2302b06391fe4d45df414e6eeb584cc28edbc797458469969bb262e13fc13afbdce615f40899f2875de07774732128141a259d6fce595057eb816e721fd51450e71d5a6833263703c8e727d42fe2a2e1dfab402f4c082122ad39a1187d014a0c08ce27877e2fa4e4340003b3bea0295489000000000000000000000000000000000000000000000000000000000000000662ba2ca994d2046470e89795a23cdec6c6f82d99c8ab60a869950f36ce704f4b74c10f5048f66089c0eb665529f1540fc9d212f6be895a599fdbf2821a664a86219664a66ce6803a6948e975274f1fc4033e0c43c80a7fcd3c34350c552ce2ed4e09d6efd8f3c023a6a48d244cf874fa8208d88a1bd144f95962b5b15aefdb34206af86db199ea099ae13839c18eb2145d2aa9792a65da1e26ac1042e76b26626bd72680c9e1d3d35fe2d89233285792a868cb805675119860621c5376cbf3c8"
        );
        data[1] = vm.parseBytes(
            "0x00069891dd4c25ea43ec1ea28126c5116de7fb9c3c00120b84c3861e42391c17000000000000000000000000000000000000000000000000000000001f8bd618000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000300010001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200003d5a1e39f957e312e307d535c8c28315172442ae0c39d9488e908c3762c850000000000000000000000000000000000000000000000000000000067361e710000000000000000000000000000000000000000000000000000000067361e7100000000000000000000000000000000000000000000000000005e970d62bb980000000000000000000000000000000000000000000000000057c1850fd2fb880000000000000000000000000000000000000000000000000000000067376ff1000000000000000000000000000000000000000000000000369a30fa1dbe92cc00000000000000000000000000000000000000000000000036951ee162ee0060000000000000000000000000000000000000000000000000369cdb8aae6c6852000000000000000000000000000000000000000000000000000000000000000695fb070b80a04f3d4419aae4d779518e6e3011aa05783afb2c8ca53108fa17945da9704f2ecac2c2ca3c4c35b77dfa36f793dbe2e8f039eac5bc7b7509ce6955f85156d4ddc3d29e8364abf48b4d965acf25bcdb04164bc42223dc818fcb5b1c74400dd99e8025d9aebfc15308c6f763de8190b3627eade83e690e4610bcf90e216592025d30c8e7d1b90d969e995e154a91a0b46780a9770ede77a4e9d287f9af39b2a2efc45555938fa08063334e11acd9d01a880e4ed04cb5f897c2f11e7100000000000000000000000000000000000000000000000000000000000000060a061d4de9e63c34864fa13f3d5ac6918f08edf3ff947173c2325c56175ea11466531764fb5c2443a0e4b25924f7113e26669cfd9e42477c18454ed27df45b987476f8166747b1059b7ce7a30e165a613198a39dc60796f6eaf1b9765e3456032d2ef5556a3c0ff917fbafa7f139e0b03ee5a0caf0f9641fd72f9d8cae9bd0ac28c0e147aa4d0940f608c71eba4a33c8c4a685d1d3b72abbd16b9cb950100daa1c6375d9894d75577a47e93acb6da0d263889d290530bfd305bff6f538fee1c5"
        );

        SetPricesParams memory oracleParams = SetPricesParams({ tokens: tokens, providers: providers, data: data });

        vm.startPrank(ORDER_KEEPER);

        IOrderHandler orderHandlerOn = IOrderHandler(0xB0Fc2a48b873da40e7bc25658e5E6137616AC2Ee);

        uint256 numberOfAccounts =
            dataStore.getBytes32Count(getAccountListKey(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2));

        orderHandlerOn.executeOrder(key, oracleParams);

        assertEq(dataStore.getBytes32Count(getAccountListKey(address(gmxHandler))), numberOfAccounts + 1);
        bytes32 positionKey = getPositionKey(
            address(gmxHandler),
            0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
            0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            true
        );

        PositionProps memory userPosition = reader.getPosition(address(dataStore), positionKey);

        assertEq(userPosition.addresses.account, address(gmxHandler));
        assertEq(userPosition.numbers.sizeInUsd, 209517740254460100375000000000000000);
        assertEq(userPosition.flags.isLong, true);

        vm.stopPrank();

        return key;
    }

    function testGMX__CreateNewOrderMock() public {
        vm.roll(274428852);

        exchangeRouter = IExchangeRouter(0x69C527fC77291722b52649E45c838e41be8Bf5d5);

        console.log("ETH balance", (0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2).balance);
        console.log("USDC_BALANCE", IERC20(USDC_ARB).balanceOf(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2));

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory params = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: 0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
                initialCollateralToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 209517740254460100375000000000000000,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 3947042505160081271952838,
                executionFee: 275023333689000,
                callbackGasLimit: 0,
                minOutputAmount: 0
            }),
            orderType: GMXOrderType.MarketIncrease, // Example: Market increase position
            decreasePositionSwapType: DecreasePositionSwapType.NoSwap, // Example: No swap
            isLong: true, // Example: Long position
            shouldUnwrapNativeToken: false, // Example: Do not unwrap native token
            autoCancel: false, // Example: Do not auto-cancel
            referralCode: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        bytes memory data2 = abi.encodeWithSelector(exchangeRouter.createOrder.selector, params);

        bytes[] memory multicallData = new bytes[](3);

        //call exchangeRouter sendWNT tokens to pay fee.
        bytes memory sendExecutionFeeData = abi.encodeWithSelector(
            exchangeRouter.sendWnt.selector, 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5, 275023333689000
        );

        //send collateral
        bytes memory sendCollateralData = abi.encodeWithSelector(
            exchangeRouter.sendTokens.selector, USDC_ARB, 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5, 7727441812
        );

        multicallData[0] = sendExecutionFeeData;
        multicallData[1] = sendCollateralData;
        multicallData[2] = data2;

        bytes32 key = getOrderKey();

        transferUSDC(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2, 7727441812);

        vm.startPrank(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2);

        IERC20(USDC_ARB).approve(0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6, 7727441812);

        exchangeRouter.multicall{ value: 275023333689000 }(multicallData);

        vm.stopPrank();

        vm.roll(274428861);
        // //271618105
        vm.warp(1720979279);

        address[] memory tokens = new address[](2);
        address[] memory providers = new address[](2);
        bytes[] memory data = new bytes[](2);

        tokens[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        tokens[1] = 0xA1b91fe9FD52141Ff8cac388Ce3F10BFDc1dE79d;

        providers[0] = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;
        providers[1] = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;

        data[0] = vm.parseBytes(
            "0x00064c28ccf99cc505d648ffcbc4c2c613859826fd4552841a6822b51800d961000000000000000000000000000000000000000000000000000000001f291106000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000003000101000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd9920000000000000000000000000000000000000000000000000000000067361e710000000000000000000000000000000000000000000000000000000067361e7100000000000000000000000000000000000000000000000000005e970d62bb980000000000000000000000000000000000000000000000000057c1850fd2fb880000000000000000000000000000000000000000000000000000000067376ff10000000000000000000000000000000000000000000000000ddff7b537fce0000000000000000000000000000000000000000000000000000ddfda1f3ce4ac000000000000000000000000000000000000000000000000000de072f51b483a840000000000000000000000000000000000000000000000000000000000000006032be3c7fddb6061f2d795cf1b4baacfad71ac72be85b7ca2d09cad90716a07d067e959655a83bd4701a28c7dac284a1911a32d94ce75d5bfe8967e2d488b6222a5523f78e94f794cc4d20ab43602c2302b06391fe4d45df414e6eeb584cc28edbc797458469969bb262e13fc13afbdce615f40899f2875de07774732128141a259d6fce595057eb816e721fd51450e71d5a6833263703c8e727d42fe2a2e1dfab402f4c082122ad39a1187d014a0c08ce27877e2fa4e4340003b3bea0295489000000000000000000000000000000000000000000000000000000000000000662ba2ca994d2046470e89795a23cdec6c6f82d99c8ab60a869950f36ce704f4b74c10f5048f66089c0eb665529f1540fc9d212f6be895a599fdbf2821a664a86219664a66ce6803a6948e975274f1fc4033e0c43c80a7fcd3c34350c552ce2ed4e09d6efd8f3c023a6a48d244cf874fa8208d88a1bd144f95962b5b15aefdb34206af86db199ea099ae13839c18eb2145d2aa9792a65da1e26ac1042e76b26626bd72680c9e1d3d35fe2d89233285792a868cb805675119860621c5376cbf3c8"
        );
        data[1] = vm.parseBytes(
            "0x00069891dd4c25ea43ec1ea28126c5116de7fb9c3c00120b84c3861e42391c17000000000000000000000000000000000000000000000000000000001f8bd618000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000300010001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200003d5a1e39f957e312e307d535c8c28315172442ae0c39d9488e908c3762c850000000000000000000000000000000000000000000000000000000067361e710000000000000000000000000000000000000000000000000000000067361e7100000000000000000000000000000000000000000000000000005e970d62bb980000000000000000000000000000000000000000000000000057c1850fd2fb880000000000000000000000000000000000000000000000000000000067376ff1000000000000000000000000000000000000000000000000369a30fa1dbe92cc00000000000000000000000000000000000000000000000036951ee162ee0060000000000000000000000000000000000000000000000000369cdb8aae6c6852000000000000000000000000000000000000000000000000000000000000000695fb070b80a04f3d4419aae4d779518e6e3011aa05783afb2c8ca53108fa17945da9704f2ecac2c2ca3c4c35b77dfa36f793dbe2e8f039eac5bc7b7509ce6955f85156d4ddc3d29e8364abf48b4d965acf25bcdb04164bc42223dc818fcb5b1c74400dd99e8025d9aebfc15308c6f763de8190b3627eade83e690e4610bcf90e216592025d30c8e7d1b90d969e995e154a91a0b46780a9770ede77a4e9d287f9af39b2a2efc45555938fa08063334e11acd9d01a880e4ed04cb5f897c2f11e7100000000000000000000000000000000000000000000000000000000000000060a061d4de9e63c34864fa13f3d5ac6918f08edf3ff947173c2325c56175ea11466531764fb5c2443a0e4b25924f7113e26669cfd9e42477c18454ed27df45b987476f8166747b1059b7ce7a30e165a613198a39dc60796f6eaf1b9765e3456032d2ef5556a3c0ff917fbafa7f139e0b03ee5a0caf0f9641fd72f9d8cae9bd0ac28c0e147aa4d0940f608c71eba4a33c8c4a685d1d3b72abbd16b9cb950100daa1c6375d9894d75577a47e93acb6da0d263889d290530bfd305bff6f538fee1c5"
        );

        SetPricesParams memory oracleParams = SetPricesParams({ tokens: tokens, providers: providers, data: data });

        orderHandler = new OrderHandler(roleStore, dataStore, eventEmitter, oracle, orderVault, swapHandler, refStorage);

        vm.etch(address(0xB0Fc2a48b873da40e7bc25658e5E6137616AC2Ee), address(orderHandler).code);

        vm.startPrank(ORDER_KEEPER);

        IOrderHandler orderHandlerOn = IOrderHandler(0xB0Fc2a48b873da40e7bc25658e5E6137616AC2Ee);

        uint256 numberOfAccounts =
            dataStore.getBytes32Count(getAccountListKey(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2));

        console.log("numberOfAccounts", numberOfAccounts);

        orderHandlerOn.executeOrder(key, oracleParams);

        //0xc92751637f19215cc24c3ec403f62f02d1c8e7e15fa1a1c3a13df7e4701b3edc

        assertEq(
            dataStore.getBytes32Count(getAccountListKey(0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2)),
            numberOfAccounts + 1
        );
        bytes32 positionKey = getPositionKey(
            0xb2A9137Dbb99CB4db4cD99e0d5A431aC38E6EeE2,
            0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
            0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            true
        );
        console.logBytes32(positionKey);

        PositionProps memory userPosition = reader.getPosition(address(dataStore), positionKey);

        assertEq(userPosition.numbers.sizeInUsd, 209517740254460100375000000000000000);
        assertEq(userPosition.flags.isLong, true);
    }

    function getPositionKey(address account, address market, address collateralToken, bool isLong)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(account, market, collateralToken, isLong));
    }

    function getAccountListKey(address account) public pure returns (bytes32) {
        bytes32 ACCOUNT_POSITION_LIST = keccak256(abi.encode("ACCOUNT_POSITION_LIST"));

        return keccak256(abi.encode(ACCOUNT_POSITION_LIST, account));
    }

    function getOrderKey() public view returns (bytes32 key) {
        IDataStore datastore = IDataStore(GMX__DATA_STORE);

        uint256 nonce = datastore.getUint(keccak256(abi.encode("NONCE"))) + 1;
        key = keccak256(abi.encode(GMX__DATA_STORE, nonce));
    }

    /*//////////////////////////////////////////////////////////////
                                  VELA
    //////////////////////////////////////////////////////////////*/

    // function testUserFundingManager__VELA() public {
    //     transferUSDC(ALICE, 1_000e6);

    //     uint32 lastTime = uint32(block.timestamp);

    //     vm.startPrank(ALICE);
    //     IERC20(USDC_ARB).approve(address(fundManager), 1_000e6);
    //     fundManager.deposit(1_000e6);

    //     skip(5 minutes);

    //     UserDepositDetails memory aliceDepositDetailsAfter = fundManager.userDepositDetails(ALICE);

    //     assertEq(aliceDepositDetailsAfter.amountUtilized, 0);
    //     assertEq(aliceDepositDetailsAfter.amountUnutilized, 1_000e6);
    // }

    // function createNewPosition__VELA() internal {
    //     transferUSDC(ALICE, 1_000e6);

    //     UserDepositDetails memory aliceDepositDetailsPrior = fundManager.userDepositDetails(ALICE);

    //     vm.startPrank(ALICE);
    //     IERC20(USDC_ARB).approve(address(fundManager), 1_000e6);
    //     fundManager.deposit(1_000e6);

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

    //     uint256 posId = IPositionVault(POSITION_VAULT).lastPosId();

    //     vm.startPrank(SAY_TRADER);
    //     controller.openStrategy(address(velaHandler), address(0), 1_000e6, true, OrderType.MARKET, data);

    //     // Order memory newOrder = IOrderVault(ORDER_VAULT).getOrder(uint256 _posId);
    // }

    // function testVela___AddNewPosition() public {
    //     transferUSDC(ALICE, 1_000e6);

    //     UserDepositDetails memory aliceDepositDetailsPrior = fundManager.userDepositDetails(ALICE);

    //     vm.startPrank(ALICE);
    //     IERC20(USDC_ARB).approve(address(fundManager), 1_000e6);
    //     fundManager.deposit(1_000e6);

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

    //     vm.startPrank(SAY_TRADER);
    //     controller.openStrategy(address(velaHandler), address(0), 1_000e6, true, OrderType.MARKET, data);

    //     // UserDepositDetails memory aliceDepositDetailsAfter = fundManager.userDepositDetails(ALICE);

    //     // assertEq(aliceDepositDetailsAfter.amountUtilized, aliceDepositDetailsPrior.amountUtilized + 1_000e6);
    //     // assertEq(aliceDepositDetailsAfter.amountUnutilized, aliceDepositDetailsPrior.amountUnutilized);
    //     //todo: add assertions
    // }
}
