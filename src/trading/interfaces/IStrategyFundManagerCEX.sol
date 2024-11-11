// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC4626 } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title IStrategyFundManagerCEX
 * @notice Interface for the StrategyFundManagerCEX contract
 */
interface IStrategyFundManagerCEX is IERC4626 {


    /// @notice Returns the amount of funds currently being used in trading
    function fundsInTrading() external view returns (uint256);

    /// @notice Returns the address of the strategy controller
    function controller() external view returns (address);

    /**
     * @notice Allows controller to take funds for a strategy
     * @param strategy Address of the strategy
     * @param amount Amount to take
     */
    function fundStrategy(address strategy, uint256 amount) external;

    /**
     * @notice Return funds from strategy with PnL
     * @param amount Amount being returned
     * @param pnl Profit (positive) or loss (negative)
     */
    function returnStrategyFunds(uint256 amount, int256 pnl) external;

    /**
     * @notice Update controller address
     * @param newController New controller address
     */
    function setController(address newController) external;
}