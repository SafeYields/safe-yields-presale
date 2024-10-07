// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldAirdrop } from "./interfaces/ISafeYieldAirdrop.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./interfaces/ISafeYieldLockUp.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SafeYieldAirdrop is ISafeYieldAirdrop, Ownable2Step, Pausable {
    using SafeERC20 for ISafeToken;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS AND IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public immutable merkleRoot;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeToken public sayToken;
    ISafeYieldStaking public staking;
    mapping(address user => bool claimed) public hasClaimed;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AllSayMinted(uint256 indexed amount);
    event SayTokenAddressUpdated(address indexed newSayToken);
    event StakingAddressUpdated(address indexed newStaking);
    event SayTokensClawedBack(address indexed admin, uint256 indexed amount);
    event sayTokenAirdropClaimed(address indexed user, uint256 indexed amount);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SYA_INVALID_ADDRESS();
    error SYA__INVALID_PROOF();
    error SYA__INVALID_AMOUNT();
    error SYA__INVALID_MERKLE_ROOT();
    error SYA__TOKENS_CLAIMED();
    error SYA__INVALID_CLAIM();

    constructor(address _sayToken, address _staking, bytes32 _merkleRoot, address protocolAdmin)
        Ownable(protocolAdmin)
    {
        if (_sayToken == address(0) || protocolAdmin == address(0) || _staking == address(0)) {
            revert SYA_INVALID_ADDRESS();
        }
        if (_merkleRoot == bytes32(0)) revert SYA__INVALID_MERKLE_ROOT();

        sayToken = ISafeToken(_sayToken);
        staking = ISafeYieldStaking(_staking);

        merkleRoot = _merkleRoot;
    }

    function stakeAndVestSayTokens(uint256 amount, bytes32[] calldata merkleProof) external override whenNotPaused {
        if (amount == 0) revert SYA__INVALID_AMOUNT();
        if (merkleProof.length == 0) revert SYA__INVALID_PROOF();

        if (hasClaimed[msg.sender]) revert SYA__TOKENS_CLAIMED();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));

        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert SYA__INVALID_CLAIM();
        }

        hasClaimed[msg.sender] = true;

        sayToken.approve(address(staking), amount);

        staking.stakeFor(msg.sender, uint128(amount), true);
    }

    function updateSayToken(address newSayToken) external onlyOwner {
        if (newSayToken == address(0)) revert SYA_INVALID_ADDRESS();

        sayToken = ISafeToken(newSayToken);

        emit SayTokenAddressUpdated(newSayToken);
    }

    function updateStaking(address newStaking) external onlyOwner {
        if (newStaking == address(0)) revert SYA_INVALID_ADDRESS();

        staking = ISafeYieldStaking(newStaking);

        emit StakingAddressUpdated(newStaking);
    }

    function clawBackSayTokens(uint256 amount) external override onlyOwner {
        if (amount == 0) revert SYA__INVALID_AMOUNT();

        sayToken.transfer(owner(), amount);

        emit SayTokensClawedBack(msg.sender, amount);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }
}
