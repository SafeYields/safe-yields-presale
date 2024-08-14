// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { BaseStrategyHandler } from "../Base/BaseStrategyHandler.sol";

/**
 * @title GMXHandler
 * @dev Manages the opening, modification, and closing of trading strategies on the VELA exchange
 *  including order fulfillment and cancellations.
 * @author 0xm00k
 */
contract VelaHandler { /*is BaseStrategyHandler*/
    constructor(
        address _positionVault,
        address _usdc,
        address _controller,
        address _fundManager,
        string memory _exchangeName
    ) { }

    function openStrategy(bytes memory, bytes memory) external payable returns (bytes32) { }

    function cancelOrder(bytes memory) external { }

    function modifyStrategy(bytes memory) external payable { }

    function exitStrategy(uint128, bytes memory) external payable { }

    function getStrategyPositionId(uint128 controllerStrategyId)
        external
        view
        returns (uint256 id256, bytes32 idBytes32)
    { }
}
