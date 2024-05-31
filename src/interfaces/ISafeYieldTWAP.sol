// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ISafeYieldTWAP {
    function getTwap(address _tokenIn, address _tokenOut, uint32 elapsedSeconds, uint24 _fee)
        external
        view
        returns (uint256);

    function getTwap(address uniV3Pool, uint32 elapsedSeconds) external view returns (uint256);
}
