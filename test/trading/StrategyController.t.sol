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
    SetPricesParams,
    CreateOrderParamsNumbers
} from "src/trading/handlers/gmx/types/GMXTypes.sol";

contract StrategyControllerTest is SafeYieldTradingBaseTest {
    address public USDC_WHALE_ARB = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;
    address WETH_ARB = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address GMX__ETH_USD = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
    address public ORDER_KEEPER = 0xE47b36382DC50b90bCF6176Ddb159C4b9333A7AB;
    address public CHAIN_LNK_PROVIDER = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;

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

    function testGMX__AddNewOrder() public returns (bytes32) {
        vm.roll(264223623);

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
        bytes32 key = testGMX__AddNewOrder();

        bytes memory exchangeData = abi.encodeWithSelector(IExchangeRouter.cancelOrder.selector, key);

        skip(300);

        vm.prank(SAY_TRADER);
        controller.cancelStrategy(address(gmxHandler), exchangeData);

        assertEq(IERC20(USDC_ARB).balanceOf(address(gmxHandler)), 10e6);
    }

    function testGMX__ExecuteOrder() public {
        bytes32 key = testGMX__AddNewOrder();

        //SetPricesParams
        address[] memory tokens = new address[](2);
        address[] memory providers = new address[](2);
        bytes[] memory data = new bytes[](2);

        tokens[0] = USDC_ARB;
        tokens[1] = WETH_ARB;

        providers[0] = CHAIN_LNK_PROVIDER;
        providers[1] = CHAIN_LNK_PROVIDER;

        data[0] = "";
        data[1] = "";

        /**
         * const data = ethers.utils.defaultAbiCoder.encode(
         *   ["tuple(address, uint256, uint256, uint256, uint256, uint256, bytes32, uint256[], uint256[], bytes[])"],
         *   [
         *     [
         *       token,
         *       signerInfo,
         *       precision,
         *       minOracleBlockNumber,
         *       maxOracleBlockNumber,
         *       oracleTimestamp,
         *       blockHash,
         *       signedMinPrices,
         *       signedMaxPrices,
         *       signatures,
         *     ],
         *   ]
         * );
         *      const oracleSalt = hashData(["uint256", "string"], [chainId, "xget-oracle-v1"]);
         */

        // data[0] = abi.encodePacked(
        //     0x0006f100c86a0007ed73322d6e26606c9985fd511be9d92cf5af6b3dda8143c7000000000000000000000000000000000000000000000000000000001a4d8d08000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000030001000100000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae900000000000000000000000000000000000000000000000000000000670a820500000000000000000000000000000000000000000000000000000000670a82050000000000000000000000000000000000000000000000000000766c0366cf3400000000000000000000000000000000000000000000000000668a6d1af1e76c00000000000000000000000000000000000000000000000000000000670bd3850000000000000000000000000000000000000000000000853a96730c2091a00000000000000000000000000000000000000000000000008538e019978937ae000000000000000000000000000000000000000000000000853cf2d9ec8c56600000000000000000000000000000000000000000000000000000000000000000064310ad7eba5c3baf647941a1c1e325c3afb50e92b9fd280d5285dbcbb3b78360d1215d6c001e524a1db63a7a5c110f2f8ccdc04120ee7db385615d48a9ea2a7181ee251ab22b91f79ddc34339b905b3f7fbf06d80524c0e6fb4f60bb6e40b47a18ea99d69e6897fbb2a4cd6b01e3bc2ddf4ecae9f9566e49d12f1d0461c81047fb963f6402abc2b469b48b91b806d1091d0adadcb1aa9225149db0f1d30e2bd3b151c01a83c9d7b4a9f531d928eed59ed1f82aab0ee530ff69569b714ca4a62800000000000000000000000000000000000000000000000000000000000000067baa3162503e64767b1e5bfb738db88d03b574d52068a2b5d534e53ebcb4e62409ede1b6b6e2f06d7627b679b32f6a48c16badfb2987fc514feb59d95c880c0c6254e0d5554ed26cdbf42aee9fbbdc5030e526bc9a84361e02aef2158fcebeb73a9a1046e99726ab1da5c4f3e21becff329212d55120bfb85502a13207e3917e0f830e2141db6cc3020fefe7b4f318509ce2671068fb8db2b321cf89c97548e828c12065c0717ae69266cf92aac134740ebfecca1b699ca430bda95efcec04c8
        // );
        // data[1] = abi.encodePacked(
        //     0x00064c28ccf99cc505d648ffcbc4c2c613859826fd4552841a6822b51800d9610000000000000000000000000000000000000000000000000000000019be450d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000003000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd99200000000000000000000000000000000000000000000000000000000670a820500000000000000000000000000000000000000000000000000000000670a82050000000000000000000000000000000000000000000000000000766b2098ef5c00000000000000000000000000000000000000000000000000668a6d1af1e76c00000000000000000000000000000000000000000000000000000000670bd3850000000000000000000000000000000000000000000000000de077f66dfffacc0000000000000000000000000000000000000000000000000de02e470eaca0000000000000000000000000000000000000000000000000000de0a59bb7df5a48000000000000000000000000000000000000000000000000000000000000000689176acc04433a1cd0866b0d5a76c926fe4597ed4970fc82e4213fe69ba948b7d25fd692b23bccb8908a0871a7bb2ad13a5a0ed0e646488eaa44c2e849e8d85238457676a106abef00eb1c829aea68e48ac70e9169aee3a4c784be38161ad2dad78b3caefc4d0f3673fafeed3f06e5f0e86b5a4fe27ae5a7f36467780f4e676c3c68e7a7e4f709fdd072e16cae2281edca5bd64cb3ff4f93721113031e8cf3c3bf97e55574d68d50bbc4a8f288e63ecfbf2f465196a37af41079ad4396589470000000000000000000000000000000000000000000000000000000000000000635058559a3d159179e89fb6e12ac6b2aa8321dd5d8cd7dd65fb5e5a68ed1d95f23dee9354fe5436d5aab2a5940a20a941b598e9c1500486de60d3b94a96c38f30b559055795a137523234558791659d80e316189055b216078346706674c7b082bb4ebef15640f15983d9d024d10ce931eff946fd0d76429bc8b00ac57303dc82f07062b58b6fc4e3b2a7f2eacf3f0779119b3c771013ea573f512996f9034401601cdd205d7152136eee6db216f6a9506c7b1c48d1456eebe9b058af3259748
        // );
        // SetPricesParams memory oracleParams = SetPricesParams({ tokens: tokens, providers: providers, data: data });

        // vm.startPrank(ORDER_KEEPER);

        // orderHandler.executeOrder(key, oracleParams);
    }

    // function decodePackedData(bytes memory data)
    //     public
    //     pure
    //     returns (
    //         address token,
    //         uint256 signerInfo,
    //         uint256 precision,
    //         uint256 minOracleBlockNumber,
    //         uint256 maxOracleBlockNumber,
    //         uint256 oracleTimestamp,
    //         bytes32 blockHash,
    //         uint256[] memory signedMinPrices,
    //         uint256[] memory signedMaxPrices,
    //         bytes[] memory signatures
    //     )
    // {
    //     // Decode the data using abi.decode with the correct types
    //     (
    //         token,
    //         signerInfo,
    //         precision,
    //         minOracleBlockNumber,
    //         maxOracleBlockNumber,
    //         oracleTimestamp,
    //         blockHash,
    //         signedMinPrices,
    //         signedMaxPrices,
    //         signatures
    //     ) = abi.decode(
    //         data, (address, uint256, uint256, uint256, uint256, uint256, bytes32, uint256[], uint256[], bytes[])
    //     );
    // }

    //CreateOrder Hash : 0x6a3548a8b32a2978b572c2647a303edb47ee8c0a831a9b9ecde387e0768d473c
    //execute order Hash : 0xee6882336a795a8e09c188f1984ec37116cdd26f40206b274b02b20651de3ad8;
    //key : 0xf6d9956c9f7fda40c326dec7ce732e60f621d30ae04b2b50c59d3148d322ae89

    function testGMX__CreateNewOrderMock() public {
        vm.roll(271618105);

        IExchangeRouter exchangeRouter = IExchangeRouter(0x69C527fC77291722b52649E45c838e41be8Bf5d5);

        console.log("ETH balance", (0x925C7F5C3b354c9aAECa5a39953d132e07f7e4a9).balance);

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory params = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: 0x925C7F5C3b354c9aAECa5a39953d132e07f7e4a9,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x0418643F94Ef14917f1345cE5C460C37dE463ef7,
                initialCollateralToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 319445030882244258201600000000000,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 2381680661097322893083175,
                executionFee: 75092875000000,
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

        bytes[] memory multicallData = new bytes[](3);

        //call exchangeRouter sendWNT tokens to pay fee.
        bytes memory sendExecutionFeeData = abi.encodeWithSelector(
            exchangeRouter.sendWnt.selector, 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5, 75092875000000
        );

        //send collateral
        bytes memory sendCollateralData = abi.encodeWithSelector(
            exchangeRouter.sendTokens.selector, USDC_ARB, 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5, 100000000
        );

        multicallData[0] = sendExecutionFeeData;
        multicallData[1] = sendCollateralData;
        multicallData[2] = data2;

        bytes32 key = getOrderKey();

        vm.startPrank(0x925C7F5C3b354c9aAECa5a39953d132e07f7e4a9);

        IERC20(USDC_ARB).approve(0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6, 100000000);

        exchangeRouter.multicall{ value: 75092875000000 }(multicallData);

        vm.roll(271618115);

        // //SetPricesParams
        address[] memory tokens = new address[](2);
        address[] memory providers = new address[](2);
        bytes[] memory data = new bytes[](2);

        tokens[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        tokens[1] = 0xA1b91fe9FD52141Ff8cac388Ce3F10BFDc1dE79d;

        providers[0] = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;
        providers[1] = 0x83cBb05AA78014305194450c4AADAc887fe5DF7F;

        data[0] = bytes(
            "0x00064c28ccf99cc505d648ffcbc4c2c613859826fd4552841a6822b51800d961000000000000000000000000000000000000000000000000000000001de1b814000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000003000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd99200000000000000000000000000000000000000000000000000000000672b544f00000000000000000000000000000000000000000000000000000000672b544f00000000000000000000000000000000000000000000000000006e8d7ab1d3a4000000000000000000000000000000000000000000000000005ff3f45f823d4800000000000000000000000000000000000000000000000000000000672ca5cf0000000000000000000000000000000000000000000000000de091be1a1f095c0000000000000000000000000000000000000000000000000de04077ab91e0000000000000000000000000000000000000000000000000000de09ee1d1be74000000000000000000000000000000000000000000000000000000000000000006f9652b54ec38dee17e2981310c46c80ddc8da0c033919a059cbf51d00088769a2687251e7cf84769113e1f2ce52f903f13eb4dc6f94d5f96bb48091aebcb0e35ca8cca93a380766799cc38931cf1075c9d6c820fc41f11dc9d075b68bfde8d1fae0c446b4e76cb652be01d85cb185f10bae409bcffc6d5f0df82317029646d1fd032f0e14110c35c98e5230b6384b5e9ecbe39dfda4156aea7f1370d76c9b11b03a385b60250e51eb3f3daf09df8ebc34e57485422920c8aa995d21759b17d7c000000000000000000000000000000000000000000000000000000000000000619e4fc5a223b9814d4c09bde405105b2c1dc5de5e11d445fef67f3154825c61243050caafbd1080fb1ceb60c719baf0bc6b606c5f46bb797e88cab0f8dc829c042bb72894d82a27a2d1aa34cb56a397b53c65f3b8c691844241348a537ca9b75510c39c25ff9a128430e47fba6f45ea99315a016dc2ecba8197693d4fc93a3f50084c61b2edaf0dc51045f81b453f9e317c52d7f85a53cca568a481d20d22e1b261cdfa95e4c0047c9bcc4a337a991ca08fcff49f308d47926ded8d1aa37489c"
        );
        data[1] =
            "0x00069891dd4c25ea43ec1ea28126c5116de7fb9c3c00120b84c3861e42391c17000000000000000000000000000000000000000000000000000000001e415c19000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000300010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200003d5a1e39f957e312e307d535c8c28315172442ae0c39d9488e908c3762c8500000000000000000000000000000000000000000000000000000000672b544f00000000000000000000000000000000000000000000000000000000672b544f00000000000000000000000000000000000000000000000000006e8d7ab1d3a4000000000000000000000000000000000000000000000000005ff3f45f823d4800000000000000000000000000000000000000000000000000000000672ca5cf00000000000000000000000000000000000000000000000020f3191b5808ce1000000000000000000000000000000000000000000000000020f0c28cdbd5c6a400000000000000000000000000000000000000000000000020f4f2ffedbc05ac00000000000000000000000000000000000000000000000000000000000000065407f392d0aa69f73c3084d264154840341754dc90919f177e448d3d51d4d45818fb374697a337c51a89b48780b1d261816cd546890532eb3bb20dff8df3b5924d1ef087ec63cde97873305325c42254fab4d811003c7f15d210f8eb836c5849d76bd62b062d22eed64d6fe211c910903f93cb2192b40680ee4c6f559e63b323d1d48f9ed99e8bb952892a83ca03fbc3ab93be4452459172de47364334f994d5d782a3500dbd05a1c2b4594f79cda0c7da1dd487d767ca1ffa864e0e68d88c2700000000000000000000000000000000000000000000000000000000000000065e5a02154e73317560e20be0e6c0f1a401a9b0d4404334aa87f93cb63da6d1fc2803fdff7e18e6e537b916396bd38b5f0f3e4a10dd290d8c01be6b64cb369a0c4c4741853796bf2d1ea23ce4f34cdca65d81d9b3136a6ff53ef73a6a5772a1e277ecae2876d0331d93bb006e79a234e0eec2168578cb20d88f07dc49b36b8ae5705e3f67edd11029140bfff87eadcebdb96ffb2eec11932417eb3efb4724973e3c61ceb6a809250620cabfb9b9b629ae467fd29cd2c7f9b0b6ab8e266a8636d2";

        SetPricesParams memory oracleParams = SetPricesParams({ tokens: tokens, providers: providers, data: data });

        vm.startPrank(ORDER_KEEPER);

        console.log(block.number);
        orderHandler.executeOrder(key, oracleParams);
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
