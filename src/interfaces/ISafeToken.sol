// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISafeToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function allocationLimits(address minter) external returns (uint256);

    function setAllocationLimit(address minter, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
