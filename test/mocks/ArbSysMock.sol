// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

contract ArbSysMock {
    function arbBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function arbBlockHash(uint256 blockNumber) external view returns (bytes32) {
        return blockhash(blockNumber);
    }
}
