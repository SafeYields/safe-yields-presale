pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract SafeToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint256 public constant MAX_SUPPLY = 200_000_000e18;

    mapping(address minter => uint256 maxMintAmount) minterLimits;

    error MaxSupplyExceeded();
    error OnlyMinterRole();
    error OnlyBurnerRole();

    constructor(
        string memory name,
        string memory symbol,
        address admin
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) public {
        if (!hasRole(MINTER_ROLE, _msgSender())) revert OnlyMinterRole();

        if (totalSupply() + amount > MAX_SUPPLY) revert MaxSupplyExceeded();

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        if (!hasRole(BURNER_ROLE, _msgSender())) revert OnlyBurnerRole();
        _burn(from, amount);
    }
}
