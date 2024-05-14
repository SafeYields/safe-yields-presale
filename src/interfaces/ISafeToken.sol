// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface ISafeToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function minterLimits(address minter) external returns (uint256);

    function setMinterLimit(address minter, uint256 amount) external;
}
