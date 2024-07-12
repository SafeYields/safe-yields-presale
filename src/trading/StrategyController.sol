// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { OrderType, Strategy } from "./types/StrategyControllerTypes.sol";
import { IStrategyFundManager } from "./interfaces/IStrategyFundManager.sol";
import { IStrategyController } from "./interfaces/IStrategyController.sol";

contract StrategyController is
    /**
     * IStrategyController,
     */
    Ownable2Step
{
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public handlerCount;
    uint128 public override strategyCount;
    address[] public strategyHandlers;
    IStrategyFundManager public fundManager;
    IERC20 public usdc;

    mapping(uint256 strategyId => Strategy) public strategies;
    mapping(address strategyHandler => uint256) public strategyHandlerIndex;

    event StrategyHandlerAdded(address strategyHandler, uint256 index);
    event StrategyHandlerRemoved(address strategyHandler);

    error SYSC_INVALID_ADDRESS();
    error SYSC_DUPLICATE_HANDLER();
    error SYSC_HANDLER_NOT_CONTRACT();
    error SYSC_INVALID_HANDLER();

    constructor(address _usdc, address _fundManager, address _protocolAdmin) Ownable(_protocolAdmin) {
        fundManager = IStrategyFundManager(_fundManager);
        usdc = IERC20(_usdc);
    }

    /**
     * struct Strategy {
     * uint256 id;
     * uint48 timestampOfStrategy;
     * uint256 amountRequested;
     * uint256 lastTotalAmountsAvailable;
     * uint256 limitPrice;
     * uint256 stopLossPrice;
     * uint256 takeProfitPrice;
     * uint256 leverage;
     * int256 pnl;
     * OrderType orderType;
     * address token;
     * address strategyHandler;
     * bool isLong;
     * bool isMatured;
     * }
     */
    //note restrict function
    function executeStrategy(address strategyHandler, bytes4 functionSelector, bytes32 params, uint256 amount)
        external
    {
        uint256 lastTotalDeposits = fundManager.fundStrategy(strategyHandler, amount);

        uint128 strategyId = ++strategyCounts[strategyHandler];

        strategies[strategyId].id = strategyId;
        strategies[strategyId].amountFunded = amount;
        strategies[strategyId].lastFundedAt = uint48(block.timestamp);
        strategies[strategyId].lastFMTotalDeposits = lastTotalDeposits;

        (bool success, bytes memory result) =
            strategyHandler.call(abi.encodeWithSelector(functionSelector, params, amount));

        if (!success) revert SY__SC_TRANSACTION_FAILED();
        //!note results.
    }

    // function updateStrategy(
    //     address strategyHandler,
    //     uint256 strategyId,
    //     uint256 amountUpdate,
    //     uint256 slUpdate,
    //     uint256 tpUpdate,
    //     uint256 leverageUpdate
    // ) external {
    //     //encode params
    // }

    function updateStrategy(
        address strategyHandler,
        uint256 strategyId,
        bytes4 functionSelector,
        bytes32 params,
        uint256 updateAmount
    ) public {
        uint256 lastTotalDeposits = fundManager.fundStrategy(strategyHandler, updateAmount);
    }

    function addStrategyHandler(address strategyHandler) external override onlyOwner {
        if (strategyHandler == address(0)) revert SYSC_INVALID_ADDRESS();
        address[] memory handlers = strategyHandlers;
        if (strategyHandlerIndex[strategyHandler] != 0 || handlers[0] == strategyHandler) {
            revert SYSC_DUPLICATE_HANDLER();
        }
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(strategyHandler)
        }
        if (codeSize == 0) revert SYSC_HANDLER_NOT_CONTRACT();

        uint256 index = handlers.length;
        strategyHandlers.push(strategyHandler);
        strategyHandlerIndex[strategyHandler] = index;
    }

    function removeStrategyHandler(address strategyHandler) external override onlyOwner {
        address[] memory handlers = strategyHandlers;
        uint256 index = strategyHandlerIndex[strategyHandler];

        if (index == 0 && handlers[0] != strategyHandler) revert SYSC_INVALID_HANDLER();
        if (handlers.length == 1) {
            delete strategyHandlers;
        } else {
            strategyHandlers[index] = handlers[handlers.length - 1];
            strategyHandlerIndex[handlers[handlers.length - 1]] = index;
            strategyHandlers.pop();
        }
        delete strategyHandlerIndex[strategyHandler];

        emit StrategyHandlerRemoved(strategyHandler);
    }

    function getStrategyHandlers() external view override returns (address[] memory) {
        return strategyHandlers;
    }
}
