// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { UserDepositDetails, Strategy } from "./types/StrategyControllerTypes.sol";
import { IStrategyFundManager } from "./interfaces/IStrategyFundManager.sol";
import { IStrategyController } from "./interfaces/IStrategyController.sol";

/**
 * @notice StrategyFundManager contract manages user deposits, allocates funds to strategies,
 *  and tracks user profits and losses, allowing users to deposit USDC, claim profits,
 *  and fund strategies through a designated strategy controller.
 */
contract StrategyFundManager is IStrategyFundManager, Ownable2Step {
    using Math for uint128;
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address user => UserDepositDetails userStats) internal userStats;
    /// @notice Tracks the amount utilized by each user in each strategy
    mapping(address user => mapping(uint8 strategyID => uint128 userAmountUtilized)) internal userUtilizations;

    IStrategyController public controller;
    IERC20 public usdc;
    uint256 public totalAmountsDeposited;
    address public protocolAdmin;
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AmountDeposited(address indexed user, uint128 indexed amount);
    event AmountWithdrawn(address indexed user, uint128 indexed amount);
    event StrategyControllerSet(address indexed controllerAddress);
    event ProfitClaimed(address indexed user, uint256 indexed pnl);
    event StrategyFunded(address indexed controller, uint256 indexed amountToFund);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SY__INVALID_ADDRESS();
    error SY__INVALID_AMOUNT();
    error SY__ONLY_CONTROLLER();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyController(address _caller) {
        if (_caller != address(controller)) revert SY__ONLY_CONTROLLER();
        _;
    }

    constructor(address _usdc, address _protocolAdmin) Ownable(_protocolAdmin) {
        if (_usdc == address(0) || _protocolAdmin == address(0)) revert SY__INVALID_ADDRESS();

        usdc = IERC20(_usdc);

        protocolAdmin = _protocolAdmin;
    }

    /**
     * @notice Allows users to deposit a specified amount of USDC.
     * @dev The amount must be at least 1e6 units (1 USDC).
     * @param amount The amount of USDC to be deposited
     */
    function deposit(uint128 amount) external override {
        if (amount < 1e6) revert SY__INVALID_AMOUNT();

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        //If the user has previously deposited, update their details
        if (userStats[msg.sender].lastDepositTimestamp != 0) {
            updateUserDetails(msg.sender);
        }

        userStats[msg.sender].lastDepositTimestamp = uint48(block.timestamp);

        userStats[msg.sender].amountUnutilized += amount;

        totalAmountsDeposited += amount;

        emit AmountDeposited(msg.sender, amount);
    }

    //TODO:
    function withdraw(uint128 amount) external override {
        emit AmountWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Sets the strategy controller to a new address
     * @dev The new controller address must not be the zero address.
     * @param _controller The address of the new strategy controller
     */
    function setStrategyController(address _controller) external override {
        if (_controller == address(0)) revert SY__INVALID_ADDRESS();

        controller = IStrategyController(_controller);

        emit StrategyControllerSet(_controller);
    }

    /**
     *  @notice Allows users to claim their profit
     *  @dev Updates user details and calculates the profit and loss (PNL) for the user. If PNL is positive,
     *       transfers the profit to the user and emits a ProfitClaimed event.
     * @return pnl The profit and loss (PNL) for the user. Returns 0 if PNL is negative.
     */
    function claimProfit() external override returns (int256 pnl) {
        updateUserDetails(msg.sender);

        pnl = pendingRewards(msg.sender);

        if (pnl < 0) return 0;

        usdc.safeTransfer(msg.sender, uint256(pnl));

        emit ProfitClaimed(msg.sender, uint256(pnl));
    }

    /**
     * @notice Funds a strategy with the specified amount
     * @dev Increases the allowance for the strategy controller by the requested amount.
     * @param amountRequested The amount of USDC to be allocated to the strategy
     * @return totalAmountsDeposited The total amount of deposits after funding the strategy
     * onlyController Ensures that only the Strategy Controller can call this function
     */
    function fundStrategy(address strategy, uint256 amountRequested)
        external
        override
        onlyController(msg.sender)
        returns (uint256)
    {
        usdc.safeIncreaseAllowance(strategy, amountRequested);

        emit StrategyFunded(strategy, amountRequested);

        return totalAmountsDeposited;
    }

    function userDepositDetails(address user) external view override returns (UserDepositDetails memory userDeposits) {
        return userStats[user];
    }

    function userCurrentUtilizations(address user, uint8 strategyId)
        external
        view
        override
        returns (uint128 amountUtilizedPerStrategy)
    {
        return userUtilizations[user][strategyId];
    }

    /**
     * @notice Calculates the profit and loss (PNL) for a given user
     * @dev Iterates through all strategies to compute the user's total PNL based on their utilization.
     * @param user The address of the user whose PNL is to be calculated
     * @return pendingPnl The total PNL for the user
     */
    function pendingRewards(address user) public view override returns (int256 pendingPnl) {
        uint256 numberOfStrategies = controller.strategyCount();

        for (uint8 strategyId; strategyId < numberOfStrategies; strategyId++) {
            //note : check gas  memory vs storage
            Strategy memory currentStrategy = controller.getStrategy(strategyId);

            pendingPnl += (currentStrategy.pnl * int256(uint256(userUtilizations[user][strategyId])))
                / int256(currentStrategy.amountRequested);
        }
    }

    /**
     * @notice Updates the details of a user's deposits and utilization across strategies
     * @dev Iterates through all strategies to allocate the user's unutilized deposit amount to strategies
     *       based on the strategy's request and availability. Updates the user's utilized and unutilized amounts
     *       accordingly.
     *  @param user The address of the user whose details are to be updated
     */
    function updateUserDetails(address user) internal {
        UserDepositDetails storage userDeposits = userStats[user];

        uint256 numberOfStrategies = controller.strategyCount();

        for (uint8 strategyId; strategyId < numberOfStrategies; strategyId++) {
            //note : check gas  memory vs storage
            Strategy memory currentStrategy = controller.getStrategy(strategyId);

            if (currentStrategy.timestampOfStrategy > userDeposits.lastDepositTimestamp) {
                // uint256 userUtilizedInStrategy = (userDeposits.amountUnutilized * currentStrategy.amountRequested)
                //     / currentStrategy.lastTotalAmountsAvailable;

                uint256 userUtilizedInStrategy = userDeposits.amountUnutilized.mulDiv(
                    currentStrategy.amountRequested, currentStrategy.lastTotalAmountsAvailable, Math.Rounding.Floor
                );
                // console.log("Strategy ID", strategyId);
                // console.log("Strategy Amount Requested", currentStrategy.amountRequested);
                // console.log("User amount Utilized Before", userDeposits.amountUtilized);

                userDeposits.amountUtilized += uint128(userUtilizedInStrategy);
                userDeposits.amountUnutilized -= uint128(userUtilizedInStrategy);

                userUtilizations[user][strategyId] = uint128(userUtilizedInStrategy);

                // console.log("User amount Utilized for Strategy", userUtilizedInStrategy);
                // console.log("User amount Unutilized before next Strategy", userDeposits.amountUnutilized);
                // console.log();

                if (userDeposits.amountUnutilized == 0) break;
            }
        }
    }
}
