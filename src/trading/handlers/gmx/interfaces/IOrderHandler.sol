// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SetPricesParams } from "../types/GMXTypes.sol";

interface IOrderHandler {
    function executeOrder(bytes32 key, SetPricesParams memory oracleParams) external;
}
