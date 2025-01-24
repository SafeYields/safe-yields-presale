// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { StrategyController, IStrategyController } from "src/trading/StrategyController.sol";
import { StrategyFundManager, IStrategyFundManager } from "src/trading/StrategyFundManager.sol";
import { IBaseStrategyHandler } from "src/trading/handlers/Base/interfaces/IBaseStrategyHandler.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IExchangeRouter } from "src/trading/handlers/gmx/interfaces/IExchangeRouter.sol";
import {
    CreateOrderParams,
    CreateDepositParams,
    CreateOrderParamsAddresses,
    DecreasePositionSwapType,
    GMXOrderType,
    SetPricesParams,
    CreateOrderParamsNumbers
} from "src/trading/handlers/gmx/types/GMXTypes.sol";
import { OrderType } from "src/trading/types/StrategyControllerTypes.sol";
import { GMXHandler } from "src/trading/handlers/gmx/GMXHandler.sol";

interface IController {
    function exitStrategy(address strategyHandler, uint128 strategyId, bytes memory exchangeData) external payable;
}

contract SafeYieldTradingTest is Script {
    IController public controller = IController(0xD52dE9D9fA265Be2bC931c54d9C0C15BAa33a424);
    IStrategyFundManager public fundManager = IStrategyFundManager(0xc5254404059d5aB22F5b9fbaD5Ee44983e317296);
    GMXHandler public GMX_HANDLER = GMXHandler(payable(0x2d6625c15588BbE473E4d5F99C1581082BA05Ab6));
    address public USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        /**
         * function getGMXPositionKey(address account, address market, address collateralToken, bool isLong)
         *       function confirmOrderFulfillment(uint128 controllerStrategyId, bytes32 positionKey)
         */
        // bytes32 positionKey = GMX_HANDLER.getGMXPositionKey(
        //     address(GMX_HANDLER), 0x55391D178Ce46e7AC8eaAEa50A72D1A5a8A622Da, USDC_ARB, true
        // );
        // console.logBytes32(positionKey);

        // GMX_HANDLER.confirmOrderFulfillment(1, positionKey);
        // fundManager.setStrategyController(address(controller));

        // IERC20(USDC_ARB).approve(address(fundManager), 1100000);
        // fundManager.deposit(1100000);

        address[] memory swapPath = new address[](0);

        CreateOrderParams memory longCreateParams = CreateOrderParams({
            addresses: CreateOrderParamsAddresses({
                receiver: address(GMX_HANDLER),
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x55391D178Ce46e7AC8eaAEa50A72D1A5a8A622Da,
                initialCollateralToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                swapPath: swapPath
            }),
            numbers: CreateOrderParamsNumbers({
                sizeDeltaUsd: 1049755463036307547645125000000,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 23160444501667,
                executionFee: 72780320000000,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: GMXOrderType.MarketDecrease, // Example: Market increase position
            decreasePositionSwapType: DecreasePositionSwapType.NoSwap, // Example: No swap
            isLong: true, // Example: Long position
            shouldUnwrapNativeToken: false, // Example: Do not unwrap native token
            autoCancel: false, // Example: Do not auto-cancel
            referralCode: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        bytes memory longData = abi.encodeWithSelector(IExchangeRouter.createOrder.selector, longCreateParams);

        // //72780320000000
        // payable(GMX_HANDLER).transfer(700000000000000);
        // //00 07 00 00 00 00 00 00 00
        // controller.openStrategy(
        //     GMX_HANDLER,
        //     0x55391D178Ce46e7AC8eaAEa50A72D1A5a8A622Da,
        //     1100000,
        //     72780320000000,
        //     true,
        //     OrderType.MARKET,
        //     longData
        // );
        // controller.exitStrategy(GMX_HANDLER, strategyId, exchangeData);

        vm.stopBroadcast();
    }
}
