// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISafeYieldAirdrop {
    function setMerkleRoot(bytes32 _merkleRoot) external;

    function stakeAndVestSayTokens(uint256 amount, bytes32[] calldata merkleProof) external;

    function clawBackSayTokens(uint256 amount) external;

    function setConfig(address configs) external;

    function pause() external;

    function unpause() external;
}
