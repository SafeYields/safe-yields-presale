// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.26;

// import { IBeraReserveToken } from "./interfaces/IBeraReserveToken.sol";
// import { IBeraReserveAirdrop } from "./interfaces/IBeraReserveAirdrop.sol";
// import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// //! DEPRECATED !!!
// contract BeraReserveAirdrop is IBeraReserveAirdrop {
//     using SafeERC20 for IBeraReserveToken;
//     /*//////////////////////////////////////////////////////////////
//                         CONSTANTS AND IMMUTABLES
//     //////////////////////////////////////////////////////////////*/

//     bytes32 public immutable merkleRoot;
//     uint256 public constant AIRDROP_TOTAL_BRR_AMOUNT = 120_000e9; // 120,000 BRR (12% of total supply)

//     /*//////////////////////////////////////////////////////////////
//                             STATE VARIABLES
//     //////////////////////////////////////////////////////////////*/
//     IBeraReserveToken public bRRToken;
//     mapping(address user => bool) public hasClaimed;

//     /*//////////////////////////////////////////////////////////////
//                                  EVENTS
//     //////////////////////////////////////////////////////////////*/
//     event AllBrrMinted(uint256 indexed amount);
//     event BeraReserveAirdropClaimed(address indexed user, uint256 indexed amount);
//     /*//////////////////////////////////////////////////////////////
//                                  ERRORS
//     //////////////////////////////////////////////////////////////*/
//     // @notice Thrown if address has already claimed

//     error BERA_RESERVE_AIRDROP_CLAIMED();
//     /// @notice Thrown if address/amount are not part of Merkle tree
//     error BERA_RESERVE_AIRDROP_INVALID_CLAIM();

//     constructor(address brrToken, bytes32 _merkleRoot) {
//         bRRToken = IBeraReserveToken(brrToken);
//         merkleRoot = _merkleRoot;
//     }

//     function claimBRR(uint256 amount, bytes32[] calldata merkleProof) external override {
//         if (hasClaimed[msg.sender]) revert BERA_RESERVE_AIRDROP_CLAIMED();

//         if (!MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender, amount)))) {
//             revert BERA_RESERVE_AIRDROP_INVALID_CLAIM();
//         }

//         hasClaimed[msg.sender] = true;
//         bRRToken.safeTransfer(msg.sender, amount);

//         emit BeraReserveAirdropClaimed(msg.sender, amount);
//     }

//     //!@raiyanmook27 restrict this to an admin
//     function mintAllBRR() external override {
//         bRRToken.mint(address(this), AIRDROP_TOTAL_BRR_AMOUNT);

//         emit AllBrrMinted(AIRDROP_TOTAL_BRR_AMOUNT);
//     }

//     //!@raiyanmook27 add admin function to clawback BRR / burn BRR
// }
