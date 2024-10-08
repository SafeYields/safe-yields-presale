pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardMockToken is ERC20 {
    uint8 decimal;

    constructor(string memory name, string memory symbol, uint8 _decimal) ERC20(name, symbol) {
        decimal = _decimal;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function mint(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }
}
