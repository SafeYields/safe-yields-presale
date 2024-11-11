//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IBaseStrategyHandlerCEX
 * @notice Interface for the base strategy handler for CEX interactions
 */
interface IBaseStrategyHandlerCEX {
    /**
     * @notice Returns the address of the strategy controller
     * @return The strategy controller address
     */
    function strategyController() external view returns (address);

    /**
     * @notice Opens a new strategy position
     * @param amount Amount of tokens to use for the strategy
     * @param strategyId Unique identifier for the strategy
     * @param cexType Type of CEX to use
     * @param trader Address of the trader
     * @return Returns a bytes32 identifier for the opened position
     */
    function openStrategy(
        uint256 amount,
        uint128 strategyId,
        uint256 cexType,
        address trader
    ) external payable returns (bytes32);

    /**
     * @notice Cancels an existing order
     * @param data Encoded data containing order details
     */
    function cancelOrder(bytes memory data) external;

    /**
     * @notice Modifies an existing strategy
     * @param data Encoded data containing modification details
     */
    function modifyStrategy(bytes memory data) external payable;

    /**
     * @notice Exits an existing strategy position
     * @param finalBalance Final balance of the position
     * @param strategyId ID of the strategy to exit
     */
    function exitStrategy(
        uint256 finalBalance,
        uint128 strategyId
    ) external payable;

    /**
     * @notice Gets the position ID for a given strategy
     * @param controllerStrategyId Strategy ID from the controller
     * @return id256 Position ID as uint256
     * @return idBytes32 Position ID as bytes32
     */
    function getStrategyPositionId(uint128 controllerStrategyId)
        external
        view
        returns (uint256 id256, bytes32 idBytes32);
}