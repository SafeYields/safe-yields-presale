// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseStrategyHandler } from "../Base/BaseStrategyHandler.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CEXHandler is BaseStrategyHandler {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    enum CEXType {
        BYBIT,
        BINANCE,
        OKEX
    }

    struct CEXPosition {
        uint256 depositAmount;    // Initial deposit amount
        uint256 currentBalance;   // Current balance tracked
        address trader;           // Address of the CEX trader
        CEXType cexType;         // Which CEX this position is on
        bool isActive;           // Whether position is currently active
    }

    // Track positions per strategy
    mapping(uint128 => CEXPosition) public positions;
    // Track total balance per CEX
    mapping(CEXType => uint256) public cexBalances;

    // Track strategy order IDs
    mapping(uint128 => bytes32) public strategyOrderIds;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyOpened(
        uint128 indexed strategyId,
        CEXType indexed cexType,
        address indexed trader,
        uint256 amount,
        bytes32 orderId
    );
    event StrategyExited(
        uint128 indexed strategyId,
        uint256 finalBalance,
        int256 realizedPnl
    );

    event CEXBalanceUpdated(
        CEXType indexed cexType,
        uint256 newBalance
    );

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error CH__INVALID_CEX();
    error CH__INVALID_AMOUNT();
    error CH__INVALID_TRADER();
    error CH__STRATEGY_NOT_ACTIVE();
    error CH__STRATEGY_ALREADY_EXISTS();
    error CH__INSUFFICIENT_BALANCE();

    constructor(
        address _controller,
        address _usdc,
        address _fundManager,
        string memory _exchangeName
    ) 
        BaseStrategyHandler(_controller, _usdc, _fundManager, _exchangeName)
    {}

    /**
     * @notice Opens a new strategy and transfers funds to the trader
     * @param handlerData Encoded data containing strategy details
     * @param openStrategyData Contains CEX type and trader address
     * @return orderId Generated order ID for the strategy
     */
    function openStrategy(
        bytes memory handlerData,
        bytes memory openStrategyData
    ) external payable override onlyController returns (bytes32) {
        (uint256 amount, uint128 strategyId,,) = abi.decode(
            handlerData,
            (uint256, uint128, address, bool)
        );

        (CEXType cexType, address trader) = abi.decode(openStrategyData, (CEXType, address));
        
        if (positions[strategyId].isActive) revert CH__STRATEGY_ALREADY_EXISTS();
        if (amount == 0) revert CH__INVALID_AMOUNT();
        if (trader == address(0)) revert CH__INVALID_TRADER();

        bytes32 orderId = keccak256(abi.encodePacked(strategyId, block.timestamp, trader));
        
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
     * @notice Exits a strategy and processes returned funds
     * @param strategyId Strategy ID to exit
     * @param exitData Contains the final balance amount
     */
    function exitStrategy(
        uint128 strategyId,
        bytes memory exitData
    ) external payable override onlyController {
        CEXPosition storage position = positions[strategyId];
        if (!position.isActive) revert CH__STRATEGY_NOT_ACTIVE();

        uint256 finalBalance = abi.decode(exitData, (uint256));
        
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
    function getStrategyPositionId(
        uint128 strategyId
    ) external view override returns (uint256 id256, bytes32 idBytes32) {
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
        if (position.isActive) {
            return int256(position.currentBalance) - int256(position.depositAmount);
        }
        return 0;
    }

   
    function modifyStrategy(bytes memory) external payable override {}
    function cancelOrder(bytes memory) external override {}
    function confirmExitStrategy(bytes32) external override {}
}