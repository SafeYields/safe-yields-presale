// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { OrderType, Position, OrderInfo, ConfirmInfo } from "../types/VelaTypes.sol";

interface IPositionVault {
    /**
     * This function allows the vault to add or remove collateral from a position.
     */
    function addOrRemoveCollateral(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        bool isPlus,
        uint256 _amount
    ) external;

    function addPosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external;

    function addTrailingStop(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params
    ) external;

    function cancelPendingOrder(address _account, address _indexToken, bool _isLong, uint256 _posId) external;

    function decreasePosition(address _account, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _posId)
        external;

    /**
     * This function allows the vault to create a new position order.
     */
    function newPositionOrder(
        address _account,
        address _indexToken,
        bool _isLong,
        OrderType _orderType,
        uint256[] memory _params,
        address _refer
    ) external;

    function getPosition(address _account, address _indexToken, bool _isLong, uint256 _posId)
        external
        view
        returns (Position memory, OrderInfo memory, ConfirmInfo memory);
}
