// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { SafeToken } from "src/SafeToken.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract SafeYieldDeploymentTestnet is Script {
    IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3);
    SafeToken public safeToken;
    address public constant SY_ADMIN = 0x8478F8c1d693aB4C054d3BBC0aBff4178b8F1b0B;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        safeToken = new SafeToken();

        _createPair();

        uniswapV2Router.addLiquidityETH{ value: 0.5e18 }(
            address(safeToken), 1_000e18, 1_000e18, 0.3e18, SY_ADMIN, block.timestamp + 1000
        );
    }

    function _createPair() internal returns (address) {
        return IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(safeToken), uniswapV2Router.WETH());
    }
}
