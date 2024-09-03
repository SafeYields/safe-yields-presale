// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { OrderType } from "../types/VelaTypes.sol";

interface IVault {
    function newPositionOrder(
        address _indexToken,
        bool _isLong,
        OrderType _orderType,
        uint256[] memory _params,
        address _refer
    ) external payable;

    function addOrRemoveCollateral(address _indexToken, bool _isLong, uint256 _posId, bool isPlus, uint256 _amount)
        external;

    function addPosition(
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external payable;

    function addTrailingStop(address _indexToken, bool _isLong, uint256 _posId, uint256[] memory _params)
        external
        payable;

    function cancelPendingOrder(address _indexToken, bool _isLong, uint256 _posId) external;

    function decreasePosition(address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _posId) external;
}
