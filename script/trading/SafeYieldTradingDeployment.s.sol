// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { StrategyController } from "src/trading/StrategyController.sol";
import { StrategyFundManager } from "src/trading/StrategyFundManager.sol";
import { GMXHandler } from "src/trading/handlers/gmx/GMXHandler.sol";

contract SafeYieldTradingDeployment is Script {
    StrategyFundManager fundManager;
    StrategyController controller;
    GMXHandler gmxHandler;
    address public SAY_TRADER = 0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF;
    address public USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public GMX__EXCHANGE_ROUTER = 0x900173A66dbD345006C51fA35fA3aB760FcD843b;
    address public GMX__ORDER_VAULT = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address public GMX__DATA_STORE = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address public GMX__READER = 0x0537C767cDAC0726c76Bb89e92904fe28fd02fE1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        fundManager = new StrategyFundManager(address(USDC_ARB), SAY_TRADER);

        controller = new StrategyController(address(USDC_ARB), address(fundManager), SAY_TRADER, SAY_TRADER);

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
    }
}
