// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { OrderType, Strategy } from "./types/StrategyControllerTypes.sol";
import { IStrategyFundManager } from "./interfaces/IStrategyFundManager.sol";
import { IStrategyController } from "./interfaces/IStrategyController.sol";
import { IBaseStrategyHandler } from "./handlers/Base/interfaces/IBaseStrategyHandler.sol";

contract StrategyController is /*IStrategyController,*/ Ownable2Step {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint128 public strategyCount;
    address[] public strategyHandlers;
    IStrategyFundManager public fundManager;
    IERC20 public usdc;

    mapping(uint256 strategyId => Strategy) public strategies;
    mapping(address strategyHandler => uint256 index) public strategyHandlerIndex;

    event StrategyHandlerAdded(address strategyHandler, uint256 index);
    event StrategyHandlerRemoved(address strategyHandler);

    error SYSC_INVALID_ADDRESS();
    error SYSC_DUPLICATE_HANDLER();
    error SYSC_HANDLER_NOT_CONTRACT();
    error SYSC_INVALID_HANDLER();
    error SYSC_TRANSACTION_FAILED();

    modifier onlyValidHandler(address handler) {
        if (strategyHandlerIndex[handler] == 0 && strategyHandlers[0] != handler) revert SYSC_INVALID_HANDLER();
        _;
    }

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
        // uint256 lastTotalDeposits = fundManager.fundStrategy(strategyHandler, amount);

        // uint128 strategyId = ++strategyCount;

        // strategies[strategyId].id = strategyId;
        // strategies[strategyId].amountFunded = amount;
        // strategies[strategyId].lastFundedAt = uint48(block.timestamp);
        // strategies[strategyId].lastFMTotalDeposits = lastTotalDeposits;

        // (bool success, bytes memory result) =
        //     strategyHandler.call(abi.encodeWithSelector(functionSelector, params, amount));

        // if (!success) revert SYSC_TRANSACTION_FAILED();
        //!note results.
    }

    function openStrategy(
        address strategyHandler,
        address market,
        uint256 amount,
        bool isLong,
        bytes memory exchangeData
    ) external onlyValidHandler(strategyHandler) {
        uint256 lastTotalDeposits = fundManager.fundStrategy(strategyHandler, amount);

        uint128 strategyId = ++strategyCount;

        bytes memory handlerData = abi.encode(amount, strategyId, market, isLong);

        IBaseStrategyHandler(strategyHandler).openStrategy(handlerData, exchangeData);

        strategies[strategyId] = Strategy({
            id: strategyId,
            amountFunded: amount,
            lastFMTotalDeposits: lastTotalDeposits,
            limitPrice: 0,
            slPrice: 0,
            tpPrice: 0,
            leverage: 0,
            pnl: 0,
            orderType: OrderType.LIMIT,
            token: address(usdc),
            handler: strategyHandler,
            lastFundedAt: uint48(block.timestamp),
            isLong: isLong,
            isMatured: false
        });
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

    function addStrategyHandler(address strategyHandler) external onlyOwner {
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

    function removeStrategyHandler(address strategyHandler) external onlyOwner {
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

    function getStrategyHandlers() external view returns (address[] memory) {
        return strategyHandlers;
    }

    function getStrategy(uint256 strategyId) external view returns (Strategy memory) {
        return strategies[strategyId];
    }
}
