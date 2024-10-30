// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Order } from "../types/VelaTypes.sol";

interface IOrderVault {
    function getOrder(uint256 _posId) external view returns (Order memory);
}
