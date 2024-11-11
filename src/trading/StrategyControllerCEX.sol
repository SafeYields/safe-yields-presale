// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC4626, ERC20, IERC20, IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Gas optimized ERC4626 vault that handles multiple users efficiently
 */
contract StrategyFundManagerCEX is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Amount currently being used by strategies
    uint256 public fundsInTrading;
    
    /// @notice The strategy controller address
    address public controller;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyFunded(address indexed strategy, uint256 amount);
    event StrategyReturned(address indexed strategy, uint256 amount, int256 pnl);
    event ControllerUpdated(address indexed newController);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress();
    error OnlyController();
    error InsufficientAvailableFunds();
    error InvalidAmount();

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _controller,
        address _owner
    ) ERC4626(_asset) ERC20(_name, _symbol) Ownable(_owner) {
        if (_controller == address(0)) revert InvalidAddress();
        controller = _controller;
    }

    modifier onlyController() {
        if (msg.sender != controller) revert OnlyController();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        CORE VAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns total assets including those currently in trading
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + fundsInTrading;
    }

    /**
     * @notice Maximum amount that can be withdrawn (only available funds)
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 availableAssets = IERC20(asset()).balanceOf(address(this));
        return Math.min(
            availableAssets,
            convertToAssets(balanceOf(owner))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows controller to take funds for a strategy
     * @param strategy Address of the strategy
     * @param amount Amount to take
     */
    function fundStrategy(address strategy, uint256 amount) external onlyController {
        // Check if enough available funds
        uint256 availableFunds = IERC20(asset()).balanceOf(address(this));
        if (amount > availableFunds) revert InsufficientAvailableFunds();

        fundsInTrading += amount;
        IERC20(asset()).safeTransfer(strategy, amount);

        emit StrategyFunded(strategy, amount);
    }

    /**
     * @notice Return funds from strategy with PnL
     * @param amount Amount being returned
     * @param pnl Profit (positive) or loss (negative)
     */
    function returnStrategyFunds(uint256 amount, int256 pnl) external onlyController {
        if (amount == 0) revert InvalidAmount();
        
        fundsInTrading -= amount;
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);

        emit StrategyReturned(msg.sender, amount, pnl);
    }

    /**
     * @dev Update controller address
     */
    function setController(address newController) external onlyOwner {
        if (newController == address(0)) revert InvalidAddress();
        controller = newController;
        emit ControllerUpdated(newController);
    }
}