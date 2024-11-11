// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IRoleStore {
    function grantRole(address account, bytes32 roleKey) external;

    function getRoleCount() external view returns (uint256);
}
