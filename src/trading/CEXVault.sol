// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC4626Upgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @notice Gas optimized ERC4626 vault that handles multiple users efficiently
 */
contract CEXVault is ERC4626Upgradeable,AccessControlUpgradeable , UUPSUpgradeable {
    using SafeERC20 for IERC20;
    bytes32 public constant SAY_TRADER_ROLE = keccak256("SAY_TRADER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum amount that can be deposited across all users
    uint256 public maxTotalDeposit;

    /// @notice Whether deposits are currently allowed
    bool public depositsPaused;
    
    /// @notice Whether withdrawals are currently allowed
    bool public withdrawalsPaused;
    
    /// @notice The strategy controller address
    address public controller;

    /// @notice Amount currently being used by strategies
    uint256 public fundsInTrading;

    /// @notice Total tracked balance of assets in the vault
    uint256 private _totalAssets;

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
    event DepositWithdrawalUnpaused();

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
    ) public initializer {
        __ERC4626_init(_asset);
        __ERC20_init(_name, _symbol);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        if (_controller == address(0)) revert InvalidAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner); 
        _grantRole(ADMIN_ROLE, _owner); 
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
     * @dev Uses internal accounting instead of balanceOf to prevent manipulation
     */
    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    /**
     * @notice Deposits tokens into the vault
     * @dev Updates internal accounting of total assets
     */
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        if (depositsPaused) revert DepositsArePaused();
        if (_totalAssets + assets > maxTotalDeposit) revert MaxTotalDepositExceeded();
        
        uint256 shares = super.deposit(assets, receiver);
        _totalAssets += assets;   
        return shares;
    }
    /**
     * @notice Mints vault shares
     * @dev Updates internal accounting of total assets
     */
    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        if (depositsPaused) revert DepositsArePaused();
        
        uint256 assets = previewMint(shares);
        if (_totalAssets + assets > maxTotalDeposit) revert MaxTotalDepositExceeded();
        
        uint256 actualAssets = super.mint(shares, receiver);
        _totalAssets += actualAssets;
  
        return actualAssets;
    }
    /**
     * @notice Withdraws tokens from the vault
     * @dev Updates internal accounting of total assets
     */
    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        
        uint256 shares = super.withdraw(assets, receiver, owner);
        _totalAssets -= assets;
        
        return shares;
    }
    /**
     * @notice Redeems vault shares
     * @dev Updates internal accounting of total assets
     */
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        
        uint256 assets = super.redeem(shares, receiver, owner);
        _totalAssets -= assets;
     
        return assets;
    }
   
    /*//////////////////////////////////////////////////////////////
                        STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows controller to take funds for a trader
     * @param trader Address of the trader
     * @param amount Amount to take
     */
    function fundStrategy(address trader, uint256 amount) external onlyRole(SAY_TRADER_ROLE) {
        // Check if enough available funds
        uint256 availableFunds = _totalAssets;
        if (amount > availableFunds) revert InsufficientAvailableFunds();
        
        fundsInTrading += amount;
        IERC20(asset()).safeTransfer(trader, amount);
    
        emit StrategyFunded(trader, amount);
    }

    /**
     * @notice Return funds from strategy with PnL
     * @param trader Address of the trader
     * @param amount Amount being returned
     * @param pnl Profit (positive) or loss (negative)
     */
    function returnStrategyFunds(address trader,uint256 amount, int256 pnl) external onlyRole(SAY_TRADER_ROLE) {
        if (amount == 0) revert InvalidAmount();
        
        fundsInTrading -= amount;
        uint256 fundsToTransfer;
        if (pnl > 0) {
        fundsToTransfer = amount + uint256(pnl);
        _totalAssets+= uint256(pnl);
        }else {
        fundsToTransfer = amount - uint256(-pnl);
        _totalAssets-= uint256(-pnl);
        }
        IERC20(asset()).safeTransferFrom(trader, address(this), fundsToTransfer);
        emit StrategyReturned(trader, amount, pnl);
    }
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum total deposit allowed
     * @param newMax New maximum total deposit
     */
    function setMaxTotalDeposit(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        maxTotalDeposit = newMax;
        emit MaxTotalDepositUpdated(newMax);
    }

    /**
     * @dev Update controller address
     */
    function setController(address newController) external onlyRole(ADMIN_ROLE) {
        if (newController == address(0)) revert InvalidAddress();
        controller = newController;
        emit ControllerUpdated(newController);
    }
    /**
     * @notice Updates the withdrawal pause status
     * @param paused New pause status
     */
    function setWithdrawalsPaused(bool paused) external onlyRole(ADMIN_ROLE) {
        withdrawalsPaused = paused;
        emit WithdrawalsStatusUpdated(paused);
    }
    /**
     * @notice Updates the deposit pause status
     * @param paused New pause status
     */
    function setDepositsPaused(bool paused) external onlyRole(ADMIN_ROLE) {
        depositsPaused = paused;
        emit DepositsStatusUpdated(paused);
    }
    /**
    * @notice Pauses both deposits and withdrawals
    */
    function pauseAll() external onlyRole(ADMIN_ROLE) {
        depositsPaused = true;
        withdrawalsPaused = true;
        emit DepositWithdrawalPaused();
    }
    /**
    * @notice Unpauses both deposits and withdrawals
    */
    function unpauseAll() external onlyRole(ADMIN_ROLE) {
        depositsPaused = false;
        withdrawalsPaused = false;
        emit DepositWithdrawalUnpaused();
    }
    function _authorizeUpgrade(address) internal override onlyRole(ADMIN_ROLE) {}

    
}