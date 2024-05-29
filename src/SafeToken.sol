// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";

contract SafeToken is ISafeToken, ERC20, AccessControl {
    /*//////////////////////////////////////////////////////////////
                      IMMUTABLES & CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint256 public constant MAX_SUPPLY = 20_000_000e18;
    //Safe Token allocation addresses
    /**
     * 11,000,000e18 for staking emissions
     * 2,000,000e18 for team operations
     * 1,000,000e18 for Core contributors
     * 2,000,000e18 for future liquidity
     * 2,000,000e18 for early investors rounds
     * 2,000,000e18 for IDO
     */
    address public constant TEAM_OPERATIONS = address(0x12);
    address public constant CORE_CONTRIBUTORS = address(0x13);
    address public constant FUTURE_LIQUIDITY = address(0x14);
    address public constant EARLY_INVESTORS = address(0x15);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address receiver => uint256 amountAllocated) public allocationLimits;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MinterAllocationSet(address indexed minter, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SAFE_YIELD__ALLOCATION_LIMIT_ALREADY_SET();
    error SAFE_YIELD__MAX_MINT_ALLOC_EXCEEDED();
    error SAFE_YIELD__MAX_SUPPLY_EXCEEDED();
    error SAFE_YIELD__ONLY_MINTER_ROLE();
    error SAFE_YIELD__ONLY_BURNER_ROLE();
    error SAFE_YIELD__ONLY_ADMIN_ROLE();

    constructor(string memory name, string memory symbol, address admin) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        _mint(TEAM_OPERATIONS, 2_000_000e18);
        _mint(CORE_CONTRIBUTORS, 1_000_000e18);
        _mint(FUTURE_LIQUIDITY, 2_000_000e18);
        _mint(EARLY_INVESTORS, 2_000_000e18);
    }
    /**
     * @notice Mint new tokens
     * @param numberOfTokens Amount of tokens to mint
     * @dev Only minter role can mint new tokens
     */

    function mint(uint256 numberOfTokens) public override {
        if (!hasRole(MINTER_ROLE, _msgSender())) {
            revert SAFE_YIELD__ONLY_MINTER_ROLE();
        }
        /**
         * Check if the total supply before minting is within the
         * maximum supply limit
         */
        if (totalSupply() + numberOfTokens > MAX_SUPPLY) {
            revert SAFE_YIELD__MAX_SUPPLY_EXCEEDED();
        }
        /**
         * Check if the amount to mint is within the allocation limit
         * for the minter
         */
        if (numberOfTokens > allocationLimits[_msgSender()]) {
            revert SAFE_YIELD__MAX_MINT_ALLOC_EXCEEDED();
        }

        _mint(_msgSender(), numberOfTokens);

        /**
         * Reduce the allocation limit for the minter
         */
        allocationLimits[_msgSender()] -= numberOfTokens;
    }
    /**
     * @notice Set the allocation limit for a minter
     * @param minter Address of the minter
     * @param maxNumberOfTokens Maximum number of tokens the minter can mint
     */

    function setAllocationLimit(address minter, uint256 maxNumberOfTokens) public override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert SAFE_YIELD__ONLY_ADMIN_ROLE();
        }

        if (allocationLimits[minter] != 0) {
            revert SAFE_YIELD__ALLOCATION_LIMIT_ALREADY_SET();
        }
        /**
         * Grant the minter role to the address if it doesn't have it
         */
        if (!hasRole(MINTER_ROLE, minter)) {
            _grantRole(MINTER_ROLE, minter);
        }

        if (totalSupply() + maxNumberOfTokens > MAX_SUPPLY) {
            revert SAFE_YIELD__MAX_SUPPLY_EXCEEDED();
        }

        allocationLimits[minter] = maxNumberOfTokens;

        emit MinterAllocationSet(minter, maxNumberOfTokens);
    }

    function burn(address from, uint256 amount) public override {
        if (!hasRole(BURNER_ROLE, _msgSender())) {
            revert SAFE_YIELD__ONLY_BURNER_ROLE();
        }
        _burn(from, amount);
    }
}
