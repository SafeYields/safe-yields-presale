// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISafeYieldAirdrop {
    function vestAndStakeSayTokens(uint256 amount, bytes32[] calldata merkleProof) external;

    function mintAllSayTokens(uint256 amount) external;

    function clawBackSayTokens(uint256 amount) external;

    function pause() external;

    function unpause() external;
}
