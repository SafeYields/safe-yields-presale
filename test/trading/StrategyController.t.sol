// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldTradingBaseTest } from "../setup/SafeYieldTradingBaseTest.t.sol";
import { console } from "forge-std/Test.sol";
import { IVault } from "test/trading/IVault.sol";
import { IOrderVault } from "src/trading/handlers/vela/interfaces/IOrderVault.sol";
import { IExchangeRouter } from "src/trading/handlers/gmx/interfaces/IExchangeRouter.sol";
import { IReader } from "src/trading/handlers/gmx/interfaces/IReader.sol";
import { IDataStore } from "src/trading/handlers/gmx/interfaces/IDataStore.sol";
import { IPositionVault } from "src/trading/handlers/vela/interfaces/IPositionVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { UserDepositDetails } from "src/trading/StrategyFundManager.sol";
import { OrderType } from "src/trading/types/StrategyControllerTypes.sol";
import { Order } from "src/trading/handlers/vela/types/VelaTypes.sol";
import {
    CreateOrderParams,
    CreateDepositParams,
    CreateOrderParamsAddresses,
    DecreasePositionSwapType,
    GMXOrderType,
    CreateOrderParamsNumbers
} from "src/trading/handlers/gmx/types/GMXTypes.sol";

contract StrategyControllerTest is SafeYieldTradingBaseTest {
    address public USDC_WHALE_ARB = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;
    address WETH_ARB = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address GMX__ETH_USD = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
    address public BTC_ARB = 0x2297aEbD383787A160DD0d9F71508148769342E3;
    address public BTC_WHALE = 0x6A08D518b9f51e20CACEAda238fc105CF20b8416;

    function transferUSDC(address user, uint256 amount) public {
        vm.prank(USDC_WHALE_ARB);
        IERC20(USDC_ARB).transfer(user, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                  GMX
    //////////////////////////////////////////////////////////////*/

    function testUserDepositFundManager() public {
        transferUSDC(ALICE, 6_000e6);

        vm.startPrank(ALICE);
        IERC20(USDC_ARB).approve(address(fundManager), 6_000e6);
        fundManager.deposit(6_000e6);
        vm.stopPrank();
    }

    function testGMX__AddNewOrder() public returns(bytes32){
        vm.roll(264223624);

        testUserDepositFundManager();

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory params = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: SAY_TRADER,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: GMX__ETH_USD,
                initialCollateralToken: USDC_ARB,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 100e6,
                initialCollateralDeltaAmount: 10e6,
                triggerPrice: 0,
                acceptablePrice: 0,
                executionFee: 0,
                callbackGasLimit: 0,
                minOutputAmount: 10e6
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

        skip(10 minutes);

        bytes32 orderKey = getOrderKey();

        vm.prank(SAY_TRADER);

        controller.openStrategy(address(gmxHandler), GMX__ETH_USD, 10e6, true, OrderType.MARKET, data2);

        //! assert
        //! 1. fund manager
        //! 2. controller 
        //! 3. balance difference 

        return orderKey;
    }

    function testGMX__ModifyOrder() public {

        testGMX__AddNewOrder();
    }

    function testGMX__CancelOrder() public {

       bytes32 orderKey = testGMX__AddNewOrder();

       bytes memory exchangeData = abi.encodeWithSelector(IExchangeRouter.cancelOrder.selector,orderKey);


       skip(300);
    
       vm.prank(SAY_TRADER);
       controller.cancelStrategy(address(gmxHandler),exchangeData);

       assertEq(IERC20(USDC_ARB).balanceOf(address(gmxHandler)),10e6);
    }

    function getOrderKey() public view returns(bytes32 key) {
        IDataStore datastore = IDataStore(GMX__DATA_STORE);

        uint256 nonce =  datastore.getUint(keccak256(abi.encode("NONCE"))) + 1;
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
