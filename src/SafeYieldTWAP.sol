//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IUniswapV3Pool } from "./uniswapV3/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "./uniswapV3/interfaces/IUniswapV3Factory.sol";
import { PoolAddress } from "./uniswapV3/PoolAddress.sol";
import { TickMath } from "./uniswapV3/TickMath.sol";

contract SafeYieldTWAP {
    IUniswapV3Factory public constant UNISWAP_V3_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function isPairSupported(address _tokenA, address _tokenB, uint24 _fee) internal pure returns (bool) {
        address _pool =
            PoolAddress.computeAddress(address(UNISWAP_V3_FACTORY), PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
        if (_pool != address(0)) {
            return true;
        } else {
            return false;
        }
    }

    function getTwap(address _tokenIn, address _tokenOut, uint32 elapsedSeconds, uint24 _fee)
        public
        view
        returns (uint256)
    {
        require(isPairSupported(_tokenIn, _tokenOut, _fee), "Pair not supported");
        require(elapsedSeconds <= 900, "Seconds too high");

        address _pool =
            PoolAddress.computeAddress(address(UNISWAP_V3_FACTORY), PoolAddress.getPoolKey(_tokenIn, _tokenOut, _fee));

        uint32[] memory elapsedSecondsArray = new uint32[](2);
        elapsedSecondsArray[0] = elapsedSeconds; // from (before)
        elapsedSecondsArray[1] = 0; // to (now)

        (int56[] memory tickCumulativeArray,) = IUniswapV3Pool(_pool).observe(elapsedSecondsArray);

        uint256 _priceAverage = TickMath.getSqrtRatioAtTick(
            int24(int256(uint256(int256(tickCumulativeArray[1] - tickCumulativeArray[0])) / elapsedSeconds))
        );
        //!Note verify if no issues
        // uint256 _priceAverage =
        //     TickMath.getSqrtRatioAtTick(int24((tickCumulativeArray[1] - tickCumulativeArray[0]) / elapsedSeconds));
        return _priceAverage;
    }
}
