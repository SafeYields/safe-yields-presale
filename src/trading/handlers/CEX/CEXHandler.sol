// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseStrategyHandlerCEX } from "../Base/BaseStrategyHandlerCEX.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * Cex Vault (4626 vault)
 * Accept usdc deposits from users.
 * Pull out the funds from the vault and deposit them into the CEX.
 * Use a state variable to track all usdc deposits (do not depend on 4626 balanceOf tracking).
 * Record amounts used to fund each strategyId but do not update number of assets. (Maintain share pricing of vault).
 * When strategy is closed, pull funds back to the vault and based on pnl, update the state variable tracking all usdc deposits.
 * If strategy pnl is +ve, add to the state variable, if -ve, subtract from the state variable.
 * This is the only point we will manually change the price of the vault share.
 *
 * limit user withdrawals ***
 * When a user wants to withdraw, they should request to withdraw x amount of their share tokens.
 * Off-chain keeps will honor user's withdrawal request by sending them x amount of usdc.
 * We have to take that amount of usdc from a strategy, burn the share tokens and update the state variable tracking all usdc deposits.
 */
contract CEXHandler is BaseStrategyHandlerCEX {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/


    struct CEXPosition {
        uint256 depositAmount; // Initial deposit amount
        uint256 currentBalance; // Current balance tracked
        address trader; // Address of the CEX trader
        uint256 cexType; // Which CEX this position is on
        bool isActive; // Whether position is currently active
    }

    // Track positions per strategy
    mapping(uint128 => CEXPosition) public positions;
    // Track total balance per CEX
    mapping(uint256 => uint256) public cexBalances;

    // Track strategy order IDs
    mapping(uint128 => bytes32) public strategyOrderIds;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyOpened(
        uint128 indexed strategyId, uint256 indexed cexType, address indexed trader, uint256 amount, bytes32 orderId
    );
    event StrategyExited(uint128 indexed strategyId, uint256 finalBalance, int256 realizedPnl);

    event CEXBalanceUpdated(uint256 indexed cexType, uint256 newBalance);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error CH__INVALID_CEX();
    error CH__INVALID_AMOUNT();
    error CH__INVALID_TRADER();
    error CH__STRATEGY_NOT_ACTIVE();
    error CH__STRATEGY_ALREADY_EXISTS();
    error CH__INSUFFICIENT_BALANCE();

    constructor(address _controller, address _usdc, address _fundManager)
        BaseStrategyHandlerCEX(_controller, _usdc, _fundManager)
    { }

    /*
    * @notice Emitted when a new strategy position is opened
    * @param strategyId Unique identifier for the strategy
    * @param cexType Type of CEX where the position is opened
    * @param trader Address of the trader managing the position
    * @param amount Initial deposit amount
    * @param orderId Unique identifier for the order
    */
    function openStrategy(uint256 amount, uint128 strategyId,uint256 cexType, address trader)
        external
        payable
        override
        onlyController
        returns (bytes32)
    {

        if (positions[strategyId].isActive) revert CH__STRATEGY_ALREADY_EXISTS();
        if (amount == 0) revert CH__INVALID_AMOUNT();
        if (trader == address(0)) revert CH__INVALID_TRADER();

        bytes32 orderId = keccak256(abi.encode(strategyId, block.timestamp, trader));

        // Store position details
        positions[strategyId] = CEXPosition({
            depositAmount: amount,
            currentBalance: amount,
            trader: trader,
            cexType: cexType,
            isActive: true
        });

        // Update balances
        cexBalances[cexType] += amount;
        strategyOrderIds[strategyId] = orderId;

        // Transfer USDC to trader
        IERC20(usdcToken).safeTransfer(trader, amount);

        emit StrategyOpened(strategyId, cexType, trader, amount, orderId);

        return orderId;
    }

    /**
    * @notice Exits an existing strategy position
    * @dev Processes returned funds and updates balances
    * @param finalBalance Final balance of the position
    * @param strategyId ID of the strategy to exit
     */
    function exitStrategy(uint256 finalBalance,uint128 strategyId) external payable override onlyController {
        CEXPosition storage position = positions[strategyId];
        if (!position.isActive) revert CH__STRATEGY_NOT_ACTIVE();

        // Update balances
        cexBalances[position.cexType] = finalBalance;

        // Calculate PnL
        int256 realizedPnl = int256(finalBalance) - int256(position.depositAmount);

        // Transfer returned funds from trader
        IERC20(usdcToken).safeTransferFrom(position.trader, address(this), finalBalance);

        position.isActive = false;
        position.currentBalance = finalBalance;

        emit StrategyExited(strategyId, finalBalance, realizedPnl);
    }

    /**
     * @notice Gets the strategy position details
     * @param strategyId Strategy ID to query
     * @return id256 Strategy ID as uint256
     * @return idBytes32 Strategy ID as bytes32
     */
    function getStrategyPositionId(uint128 strategyId)
        external
        view
        override
        returns (uint256 id256, bytes32 idBytes32)
    {
        idBytes32 = strategyOrderIds[strategyId];
        id256 = uint256(strategyId);
    }

    /**
     * @notice Gets current PnL for a strategy
     * @param strategyId Strategy ID to query
     * @return pnl Current PnL for the strategy
     */
    function getStrategyPnL(uint128 strategyId) external view returns (int256 pnl) {
        CEXPosition memory position = positions[strategyId];
        if (!position.isActive) {
            return int256(position.currentBalance) - int256(position.depositAmount);
        }
        return 0;
    }

    function modifyStrategy(bytes memory) external payable override { }
    function cancelOrder(bytes memory) external override { }
    function confirmExitStrategy(bytes32) external override { }
}
