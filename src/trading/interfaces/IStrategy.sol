// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

/**
 * @title IStrategy interface
 * @notice  Standard interface for strategies
 */
interface IStrategy {
    function executeStrategy(uint128 amount) external;

    /**
     * @notice  Function to withdraw funds from the strategy
     * @param   tokenAddress address of the token to withdraw, WETH in case of ETH
     * @param   beneficiary address to receive the funds
     * @param   amount amount to withdraw
     */
    function withdraw(address tokenAddress, address beneficiary, uint256 amount, bool isERC20) external;
    /**
     * @notice  Function to get the balance of the strategy
     * @param   tokenAddress address of the token to get the balance
     * @return amount supplied + yield generated in the underlying strategy
     */
    function getBalance(address tokenAddress) external view returns (uint256 amount);
}
