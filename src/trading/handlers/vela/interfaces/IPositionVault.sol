// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

//import { OrderType, Position, OrderInfo, ConfirmInfo } from "../types/VelaTypes.sol";

interface IPositionVault {
    function lastPosId() external view returns (uint256);

    //function getPosition(uint256 _posId) external return { }

    // function getPosition(address _account, address _indexToken, bool _isLong, uint256 _posId)
    //     external
    //     view
    //     returns (Position memory, OrderInfo memory, ConfirmInfo memory);
}
