// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

enum OrderType {
    MARKET,
    LIMIT,
    STOP,
    STOP_LIMIT,
    TRAILING_STOP
}

interface IVault {
    function newPositionOrder(
        uint256 _tokenId,
        bool _isLong,
        OrderType _orderType,
        uint256[] memory _params,
        address _refer
    ) external payable;

    function deposit(address _account, address _token, uint256 _amount) external;
}
