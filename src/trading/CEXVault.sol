// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC4626Upgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @notice Gas optimized ERC4626 vault that handles multiple users efficiently
 */
contract CEXVault is ERC4626Upgradeable, OwnableUpgradeable , UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum amount that can be deposited across all users
    uint256 public maxTotalDeposit;

    /// @notice Whether deposits are currently allowed
    bool public depositsPaused;
    
    /// @notice Whether withdrawals are currently allowed
    bool public withdrawalsPaused;
    
    
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
    event DepositsStatusUpdated(bool paused);
    event WithdrawalsStatusUpdated(bool paused);
    event MaxTotalDepositUpdated(uint256 newMax);
    event TradingFundsWithdrawn(address indexed trader, uint256 amount);
    event TradingFundsReturned(address indexed trader, uint256 amount, int256 pnl);
    event DepositWithdrawalPaused();

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress();
    error OnlyController();
    error InsufficientAvailableFunds();
    error InvalidAmount();
    error DepositsArePaused();
    error WithdrawalsArePaused();
    error MaxTotalDepositExceeded();

    /**
     * @dev Initializes the contract after it has been upgraded.
     */
    function initialize(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint256 _maxTotalDeposit,
        address _controller,
        address _owner
    ) public onlyInitializing {
        __ERC4626_init(_asset);
        __ERC20_init(_name, _symbol);
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        if (_controller == address(0)) revert InvalidAddress();
        controller = _controller;
        maxTotalDeposit = _maxTotalDeposit;
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
     * @notice Deposits tokens into the vault
     * @dev Overrides the default deposit function to add max cap and pause checks
     */
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(!depositsPaused ,DepositsArePaused());
        if (totalAssets() + assets > maxTotalDeposit) revert MaxTotalDepositExceeded();
        return super.deposit(assets, receiver);
    }
    /**
     * @notice Mints vault shares
     * @dev Overrides the default mint function to add max cap and pause checks
     */
    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        require(!depositsPaused ,DepositsArePaused());
        uint256 assets = previewMint(shares);
        if (totalAssets() + assets > maxTotalDeposit) revert MaxTotalDepositExceeded();
        return super.mint(shares, receiver);
    }
    /**
     * @notice Withdraws tokens from the vault
     * @dev Overrides the default withdraw function to add pause checks
     */
    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Redeems vault shares
     * @dev Overrides the default redeem function to add pause checks
     */
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        return super.redeem(shares, receiver, owner);
    }

   
    /*//////////////////////////////////////////////////////////////
                        STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows controller to take funds for a trader
     * @param trader Address of the trader
     * @param amount Amount to take
     */
    function fundStrategy(address trader, uint256 amount) external onlyController returns(bytes32) {
        // Check if enough available funds
        uint256 availableFunds = IERC20(asset()).balanceOf(address(this));
        if (amount > availableFunds) revert InsufficientAvailableFunds();
        bytes32 orderId = keccak256(abi.encode(block.timestamp, trader));

        fundsInTrading += amount;
        IERC20(asset()).safeTransfer(trader, amount);
        depositsPaused = true;
        withdrawalsPaused = true;

        emit StrategyFunded(trader, amount);
        return orderId;
    }

    /**
     * @notice Return funds from strategy with PnL
     * @param trader Address of the trader
     * @param amount Amount being returned
     * @param pnl Profit (positive) or loss (negative)
     */
    function returnStrategyFunds(address trader,uint256 amount, int256 pnl) external onlyController {
        if (amount == 0) revert InvalidAmount();
        
        fundsInTrading -= amount;
        uint256 fundsToTransfer;
        if (pnl > 0) {
        fundsToTransfer = amount + uint256(pnl);
        }else {
        fundsToTransfer = amount - uint256(-pnl);
        }
        IERC20(asset()).safeTransferFrom(trader, address(this), fundsToTransfer);
        depositsPaused = false;
        withdrawalsPaused = false;

        emit StrategyReturned(trader, amount, pnl);
    }
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum total deposit allowed
     * @param newMax New maximum total deposit
     */
    function setMaxTotalDeposit(uint256 newMax) external onlyOwner {
        maxTotalDeposit = newMax;
        emit MaxTotalDepositUpdated(newMax);
    }

    /**
     * @dev Update controller address
     */
    function setController(address newController) external onlyOwner {
        if (newController == address(0)) revert InvalidAddress();
        controller = newController;
        emit ControllerUpdated(newController);
    }
    /**
     * @notice Updates the withdrawal pause status
     * @param paused New pause status
     */
    function setWithdrawalsPaused(bool paused) external onlyOwner {
        withdrawalsPaused = paused;
        emit WithdrawalsStatusUpdated(paused);
    }
    /**
    * @notice Pauses both deposits and withdrawals
    */
    function pauseAll() external onlyOwner {
        depositsPaused = true;
        withdrawalsPaused = true;
        emit DepositWithdrawalPaused();
    }
    function _authorizeUpgrade(address) internal override onlyOwner {}

    
}