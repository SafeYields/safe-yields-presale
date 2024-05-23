// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeToken} from "../../src/SafeToken.sol";

contract SafeMockToken is SafeToken {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) SafeToken(name, symbol, msg.sender) {}
}
