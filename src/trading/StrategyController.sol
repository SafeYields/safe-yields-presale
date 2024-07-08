// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { OrderType, Strategy } from "./types/StrategyControllerTypes.sol";
import { IStrategyFundManager } from "./interfaces/IStrategyFundManager.sol";
import { IStrategyController } from "./interfaces/IStrategyController.sol";

contract StrategyController is IStrategyController, Ownable2Step {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint128 public override strategyCount;
    address[] public strategyHandlers;
    IStrategyFundManager public fundManager;
    IERC20 public usdc;
    mapping(uint256 strategyId => Strategy) public strategies;

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
    //TODO: more params
    function executeStrategy(address strategyHandler, uint256 amount) external override {
        uint256 lastTotalDeposits = fundManager.fundStrategy(strategyHandler, amount);

        uint256 strategyId = ++strategyCount;

        strategies[strategyId].id = strategyId;
        strategies[strategyId].amountRequested = amount;
        strategies[strategyId].timestampOfStrategy = uint32(block.timestamp);
        strategies[strategyId].lastTotalAmountsAvailable = lastTotalDeposits;

        //note interact with strategy handler
    }

    function getStrategy(uint256 strategyId) external view override returns (Strategy memory) {
        return strategies[strategyId];
    }

    function closeStrategy(uint256 strategyId) external { }

    function updateStrategy(
        uint256 strategyId,
        uint256 amountUpdate,
        uint256 slUpdate,
        uint256 tpUpdate,
        uint256 leverageUpdate
    ) external override { }

    function addStrategyHandler(address strategyHandler) external override onlyOwner { }

    function removeStrategyHandler(address strategyHandler) external override onlyOwner { }

    function getStrategyHandlers() external view override returns (address[] memory) { }
}
