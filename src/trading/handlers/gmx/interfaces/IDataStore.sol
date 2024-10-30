// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IDataStore {

    function getUint(bytes32 key) external view returns (uint256);

    function getBytes32ValuesAt(bytes32 keyList, uint256 start, uint256 end) external view returns (bytes32[] memory);

    function getBytes32Count(bytes32 setKey) external view returns (uint256);
}
