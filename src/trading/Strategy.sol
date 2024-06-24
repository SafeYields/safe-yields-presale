// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IStrategy } from "./interfaces/IStrategy.sol";

contract Strategy is IStrategy {
    function executeStrategy(uint128 amount) external { }

    function withdraw(address tokenAddress, address beneficiary, uint256 amount, bool isERC20) external { }

    function getBalance(address tokenAddress) external view returns (uint256 amount) { }
}
