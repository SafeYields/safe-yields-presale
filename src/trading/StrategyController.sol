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
    IERC20 public usdcToken;

    mapping(uint256 strategyId => Strategy) public strategies;
    mapping(address strategyHandler => uint256 index) public strategyHandlerIndex;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event StrategyHandlerAdded(address strategyHandler, uint256 index);
    event StrategyHandlerRemoved(address strategyHandler);
    event StrategyExited(uint128 indexed controllerStrategyId);
    event StrategyUpdated(uint128 indexed strategyId, address indexed strategyHandler, uint256 indexed triggerPrice);
    event StrategyOpened(
        uint128 indexed strategyId,
        address indexed strategyHandler,
        address indexed market,
        uint256 amount,
        bool isLong,
        OrderType orderType,
        bytes32 orderId
    );
    event StrategyExited(
        uint128 indexed strategyId, uint256 indexed amountRequested, uint256 indexed amountReturned, int256 pnl
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SYSC__INVALID_ADDRESS();
    error SYSC__DUPLICATE_HANDLER();
    error SYSC__HANDLER_NOT_CONTRACT();
    error SYSC__INVALID_HANDLER();
    error SYSC__TRANSACTION_FAILED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyValidHandler(address handler) {
        if (strategyHandlerIndex[handler] == 0 && strategyHandlers[0] != handler) revert SYSC__INVALID_HANDLER();
        _;
    }

    constructor(address _usdcToken, address _fundManager, address _protocolAdmin) Ownable(_protocolAdmin) {
        if (_usdcToken == address(0) || _fundManager == address(0) || _protocolAdmin == address(0)) {
            revert SYSC__INVALID_ADDRESS();
        }

        fundManager = IStrategyFundManager(_fundManager);
        usdcToken = IERC20(_usdcToken);
    }

    function openStrategy(
        address strategyHandler,
        address market,
        uint256 amount,
        bool isLong,
        OrderType orderType,
        bytes memory exchangeData
    ) external payable onlyValidHandler(strategyHandler) {
        uint256 lastTotalDeposits = fundManager.fundStrategy(strategyHandler, amount);

        uint128 strategyId = ++strategyCount;

        bytes memory handlerData = abi.encode(amount, strategyId, market, isLong);

        bytes32 orderId = IBaseStrategyHandler(strategyHandler).openStrategy(handlerData, exchangeData);

        strategies[strategyId].id = strategyId;
        strategies[strategyId].amountFunded = amount;
        strategies[strategyId].lastFMTotalDeposits = lastTotalDeposits;
        strategies[strategyId].orderType = orderType;
        strategies[strategyId].token = address(usdcToken);
        strategies[strategyId].handler = strategyHandler;
        strategies[strategyId].lastFundedAt = uint48(block.timestamp);
        strategies[strategyId].isLong = isLong;
        strategies[strategyId].isMatured = false;

        emit StrategyOpened(strategyId, strategyHandler, market, amount, isLong, orderType, orderId);
    }

    function updateStrategy(
        address strategyHandler,
        uint128 strategyId,
        uint256 triggerPrice,
        bytes memory exchangeData
    ) public payable {
        IBaseStrategyHandler(strategyHandler).modifyStrategy(exchangeData);

        strategies[strategyId].triggerPrice = triggerPrice;

        emit StrategyUpdated(strategyId, strategyHandler, triggerPrice);
    }

    function exitStrategy(address strategyHandler, uint128 strategyId, bytes memory exchangeData) external payable {
        IBaseStrategyHandler(strategyHandler).exitStrategy(strategyId, exchangeData);
    }

    //!review
    function confirmExitStrategy(address strategyHandler, uint128 strategyId, bytes32 positionKey) external {
        IBaseStrategyHandler(strategyHandler).confirmExitStrategy(positionKey);

        uint256 fundsReturned = usdcToken.balanceOf(address(this));

        usdcToken.safeIncreaseAllowance(address(fundManager), fundsReturned);

        int256 pnl = int256(fundsReturned - strategies[strategyId].amountFunded);

        strategies[strategyId].pnl = pnl;
        strategies[strategyId].isMatured = true;

        fundManager.returnStrategyFunds(strategyId, fundsReturned, pnl);
    }

    function addStrategyHandler(address strategyHandler) external onlyOwner {
        if (strategyHandler == address(0)) revert SYSC__INVALID_ADDRESS();

        address[] memory handlers = strategyHandlers;

        if (strategyHandlerIndex[strategyHandler] != 0 || handlers[0] == strategyHandler) {
            revert SYSC__DUPLICATE_HANDLER();
        }

        uint256 codeSize;
        assembly {
            codeSize := extcodesize(strategyHandler)
        }
        if (codeSize == 0) revert SYSC__HANDLER_NOT_CONTRACT();

        uint256 index = handlers.length;

        strategyHandlers.push(strategyHandler);

        strategyHandlerIndex[strategyHandler] = index;

        emit StrategyHandlerAdded(strategyHandler, index);
    }

    function removeStrategyHandler(address strategyHandler) external onlyOwner {
        address[] memory handlers = strategyHandlers;
        uint256 index = strategyHandlerIndex[strategyHandler];

        if (index == 0 && handlers[0] != strategyHandler) revert SYSC__INVALID_HANDLER();
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
