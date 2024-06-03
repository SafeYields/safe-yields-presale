//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IUniswapV3Pool } from "./uniswapV3/interfaces/IUniswapV3Pool.sol";
import { OracleLibrary } from "./uniswapV3/OracleLibrary.sol";

contract SafeYieldTWAP {
    function getEstimateAmountOut(address uniswapV3Pool, address tokenIn, uint128 amountIn, uint32 secondsAgo)
        external
        view
        returns (uint256 amountOut)
    {
        address _token0 = IUniswapV3Pool(uniswapV3Pool).token0();
        address _token1 = IUniswapV3Pool(uniswapV3Pool).token1();

        require(tokenIn == _token0 || tokenIn == _token1, "invalid token");

        address tokenOut = tokenIn == _token0 ? _token1 : _token0;

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives,) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        int24 tick = int24(int256(uint256(int256(tickCumulativesDelta)) / uint256(secondsAgo)));

        if (tickCumulativesDelta < 0 && (uint256(int256(tickCumulativesDelta)) % secondsAgo != 0)) {
            tick--;
        }

        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, tokenIn, tokenOut);
    }
}
