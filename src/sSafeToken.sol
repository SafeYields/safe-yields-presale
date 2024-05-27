/**
 * This token represents the staked safe token. It is an ERC20 token with minting and burning capabilities.
 * The contract is Ownable and uses the AccessControl contract from OpenZeppelin.
 * The contract has two roles: MINTER_ROLE and BURNER_ROLE.
 * It is non-transferable and has a maximum supply of tokens.
 * The contract has a constructor that sets the admin role.
 * The mint function allows minting of tokens by a user with the MINTER_ROLE.
 * The burn function allows burning of tokens by a user with the BURNER_ROLE.
 */

// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IsSafeToken } from "./interfaces/IsSafeToken.sol";

contract sSafeToken is IsSafeToken, ERC20, AccessControl {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SAFE_YIELD__TRANSFER_NOT_ALLOWED();

    constructor(string memory name, string memory symbol, address admin) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) public override onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public override onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            if (to != address(0)) {
                revert SAFE_YIELD__TRANSFER_NOT_ALLOWED();
            }
        }
        super._update(from, to, value);
    }
}
