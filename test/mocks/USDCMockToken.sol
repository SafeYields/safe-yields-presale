pragma solidity 0.8.21;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDCMockToken is ERC20 {
    uint8 decimal;
    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimal
    ) ERC20(name, symbol) {
        decimal = _decimal;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }

    function mint(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }
}
