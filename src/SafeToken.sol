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
    /**
     * 11,000,000e18 for staking emissions
     * 2,000,000e18 for team operations
     * 1,000,000e18 for Core contributors
     * 2,000,000e18 for future liquidity
     * 2,000,000e18 for early investors rounds
     * 2,000,000e18 for IDO
     */
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 maxMintAllocated;
    mapping(address receiver => uint256 amountAllocated) public allocationLimits;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MinterAllocationSet(address indexed minter, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SAFE_YIELD__MAX_SUPPLY_EXCEEDED();
    error SAFE_YIELD__ONLY_MINTER_ROLE();
    error SAFE_YIELD__ONLY_BURNER_ROLE();
    error SAFE_YIELD__ONLY_ADMIN_ROLE();

    constructor(string memory name, string memory symbol, address admin) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    //! remove to param and mint to msg.sender instead
    function mint(address to, uint256 amount) public override {
        if (!hasRole(MINTER_ROLE, _msgSender())) {
            revert SAFE_YIELD__ONLY_MINTER_ROLE();
        }

        //! either separate checks with different custom errors or make single error with params
        if (totalSupply() + amount > MAX_SUPPLY || allocationLimits[_msgSender()] < amount) {
            revert SAFE_YIELD__MAX_SUPPLY_EXCEEDED();
        }

        _mint(to, amount);

        allocationLimits[_msgSender()] -= amount;
    }

    function setAllocationLimit(address minter, uint256 amount) public override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert SAFE_YIELD__ONLY_ADMIN_ROLE();
        }

        //! give @param minter the minter role if it doesn't have it
        if (maxMintAllocated + amount > MAX_SUPPLY) {
            revert SAFE_YIELD__MAX_SUPPLY_EXCEEDED();
        }

        maxMintAllocated += amount;
        allocationLimits[minter] = amount;

        emit MinterAllocationSet(minter, amount);
    }

    function burn(address from, uint256 amount) public override {
        if (!hasRole(BURNER_ROLE, _msgSender())) {
            revert SAFE_YIELD__ONLY_BURNER_ROLE();
        }
        _burn(from, amount);
    }
}
