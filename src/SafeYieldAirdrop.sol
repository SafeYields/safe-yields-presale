// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldAirdrop } from "./interfaces/ISafeYieldAirdrop.sol";
import { ISafeYieldConfigs } from "./interfaces/ISafeYieldConfigs.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldVesting } from "./interfaces/ISafeYieldVesting.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SafeYieldAirdrop contract
 * @dev The SafeYieldAirdrop contract facilitates the distribution of tokens (Say Tokens)
 *   to eligible users via a Merkle-based airdrop,
 *   allowing them to stake and vest their tokens (Vesting will span 5 months, with 20% of their allocation unlocked each month).
 *   It includes functionality for pausing/unpausing, clawing back unclaimed tokens,
 *   and updating the configuration and Merkle root.
 *
 * @author 0xm00k
 */
contract SafeYieldAirdrop is ISafeYieldAirdrop, Ownable2Step, Pausable {
    using SafeERC20 for ISafeToken;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeToken public sayToken;
    bytes32 public merkleRoot;
    ISafeYieldConfigs public safeYieldConfigs;
    mapping(address user => bool claimed) public hasClaimed;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MerkleRootUpdated(bytes32 indexed _merkleRoot);
    event SayTokensClawedBack(address indexed admin, uint256 indexed amount);
    event SayTokensStakedAndVested(address indexed receiver, uint256 indexed amount);
    event SafeYieldConfigUpdated(address indexed safeYieldConfigs);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SYA__INVALID_ADDRESS();
    error SYA__INVALID_PROOF();
    error SYA__INVALID_AMOUNT();
    error SYA__INVALID_MERKLE_ROOT();
    error SYA__TOKENS_CLAIMED();
    error SYA__INVALID_PROOF_LENGTH();

    constructor(address _sayToken, address _safeYieldConfigs, address protocolAdmin) Ownable(protocolAdmin) {
        if (_sayToken == address(0) || _safeYieldConfigs == address(0)) {
            revert SYA__INVALID_ADDRESS();
        }

        sayToken = ISafeToken(_sayToken);

        safeYieldConfigs = ISafeYieldConfigs(_safeYieldConfigs);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external override onlyOwner {
        if (_merkleRoot == bytes32(0)) revert SYA__INVALID_MERKLE_ROOT();

        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(_merkleRoot);
    }

    function stakeAndVestSayTokens(uint256 amount, bytes32[] calldata merkleProof) external override whenNotPaused {
        if (amount == 0) revert SYA__INVALID_AMOUNT();
        if (merkleProof.length == 0) revert SYA__INVALID_PROOF_LENGTH();

        if (hasClaimed[msg.sender]) revert SYA__TOKENS_CLAIMED();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));

        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert SYA__INVALID_PROOF();
        }

        hasClaimed[msg.sender] = true;

        ISafeYieldStaking safeYieldStaking = safeYieldConfigs.safeYieldStaking(); //cache

        sayToken.approve(address(safeYieldStaking), amount);

        safeYieldStaking.stakeFor(msg.sender, uint128(amount), true);

        emit SayTokensStakedAndVested(msg.sender, amount);
    }

    function clawBackSayTokens(uint256 amount) external override onlyOwner {
        if (amount == 0) revert SYA__INVALID_AMOUNT();

        sayToken.safeTransfer(owner(), amount);

        emit SayTokensClawedBack(owner(), amount);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function setConfig(address configs) external override onlyOwner {
        if (configs == address(0)) revert SYA__INVALID_ADDRESS();
        safeYieldConfigs = ISafeYieldConfigs(configs);

        emit SafeYieldConfigUpdated(configs);
    }
}
