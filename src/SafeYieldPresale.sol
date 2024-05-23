// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { PreSaleState, ReferrerInfo } from "./types/SafeTypes.sol";

contract SafeYieldPresale is ISafeYieldPreSale, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ISafeToken;

    /*//////////////////////////////////////////////////////////////
                    CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant PRE_SALE_CAP = 2_000_000e18;
    uint64 public constant BPS_MAX = 10_000; //100_00 is 100% in this context
    uint64 public constant USDC_PRECISION = 1e6;

    ISafeYieldStaking public immutable safeYieldStaking;
    ISafeToken public immutable safeToken;
    IERC20 public immutable usdcToken;
    IERC20 public immutable sSafeToken;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    PreSaleState public preSaleState;
    uint128 public totalSold;
    uint128 public minAllocationPerWallet;
    uint128 public maxAllocationPerWallet;
    uint128 public tokenPrice;
    uint128 public referrerCommissionUsdcBps;
    uint128 public referrerCommissionSafeTokenBps;

    mapping(address userAddress => uint128 safeTokensAllocation) public investorAllocations;
    mapping(bytes32 referrerId => ReferrerInfo referrerInfo) public referrerInfo;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensPurchased(
        address indexed buyer,
        uint128 indexed usdcAmount,
        uint128 indexed safeTokens,
        uint128 referrerCommissionUsdcBps,
        uint128 referrerCommissionSafeTokenBps,
        bytes32 referrerId
    );

    event ReferrerIdCreated(address indexed referrer, bytes32 indexed referrerId);

    event UsdcCommissionRedeemed(address indexed referrer, uint128 indexed usdcAmount);

    event SafeTokensClaimed(address indexed investor, uint128 indexed safeTokens);

    event UsdcWithdrawn(address indexed receiver, uint256 indexed amount);

    event ReferrerCommissionSet(
        uint128 indexed referrerCommissionUsdcBps, uint128 indexed referrerCommissionSafeTokenBps
    );
    event PreSaleStarted();
    event PreSaleEnded();

    event TokenPriceSet(uint128 indexed tokenPrice);

    event AllocationSet(uint128 indexed minAllocationPerWallet, uint128 indexed maxAllocationPerWallet);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SAFE_YIELD_REFERRER_MAX_WALLET_ALLOCATION_EXCEEDED();
    error SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
    error SAFE_YIELD_MAX_WALLET_ALLOCATION_EXCEEDED();
    error SAFE_YIELD_MIN_WALLET_ALLOCATION_EXCEEDED();
    error SAFE_YIELD_MAX_SUPPLY_EXCEEDED();
    error SAFE_YIELD_INVALID_USDC_AMOUNT();
    error SAFE_YIELD_INVALID_TOKEN_PRICE();
    error SAFE_YIELD_INVALID_MAX_SUPPLY();
    error SAFE_YIELD_INVALID_ALLOCATION();
    error SAFE_YIELD_PRESALE_NOT_ENDED();
    error SAFE_YIELD_UNKNOWN_REFERRER();
    error SAFE_YIELD_REFERRAL_TO_SELF();
    error SAFE_YIELD_PRESALE_NOT_LIVE();
    error SAFE_YIELD_INVALID_ADDRESS();
    error SAFE_YIELD_INVALID_USER();
    error SAFE_YIELD_ZERO_BALANCE();

    constructor(
        address _safeToken,
        address _sSafeToken,
        address _usdcToken,
        address _safeYieldStaking,
        uint128 _minAllocationPerWallet,
        uint128 _maxAllocationPerWallet,
        uint128 _tokenPrice,
        uint128 _referrerCommissionUsdc,
        uint128 _referrerCommissionSafeToken
    ) Ownable(msg.sender) {
        if (_minAllocationPerWallet > _maxAllocationPerWallet) {
            revert SAFE_YIELD_INVALID_ALLOCATION();
        }

        if (referrerCommissionUsdcBps > BPS_MAX || referrerCommissionSafeTokenBps > BPS_MAX) {
            revert SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
        }

        if (_tokenPrice == 0) revert SAFE_YIELD_INVALID_TOKEN_PRICE();
        if (
            _safeToken == address(0) || _usdcToken == address(0) || _sSafeToken == address(0)
                || _safeYieldStaking == address(0)
        ) revert SAFE_YIELD_INVALID_ADDRESS();

        safeToken = ISafeToken(_safeToken);
        usdcToken = IERC20(_usdcToken);
        sSafeToken = IERC20(_sSafeToken);

        safeYieldStaking = ISafeYieldStaking(_safeYieldStaking);

        minAllocationPerWallet = _minAllocationPerWallet;
        maxAllocationPerWallet = _maxAllocationPerWallet;

        tokenPrice = _tokenPrice;

        referrerCommissionUsdcBps = _referrerCommissionUsdc;
        referrerCommissionSafeTokenBps = _referrerCommissionSafeToken;

        preSaleState = PreSaleState.NotStarted;
    }

    /**
     * @dev Pause the presale
     * @notice This function can only be called by the owner
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the presale
     * @notice This function can only be called by the owner
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @dev Start the presale
     * @notice This function can only be called by the owner
     */
    function startPresale() external override onlyOwner {
        preSaleState = PreSaleState.Live;
        emit PreSaleStarted();
    }

    /**
     * @dev End the presale
     * @notice This function can only be called by the owner
     */
    function endPresale() external override onlyOwner {
        preSaleState = PreSaleState.Ended;
        emit PreSaleEnded();
    }

    /**
     * @dev Buy safe tokens with USDC
     * @param investor the address of the investor
     * @param usdcAmount the amount of USDC to be used to buy the safe tokens
     * @param referrerId the referrer id of a referrer
     */
    function deposit(address investor, uint128 usdcAmount, bytes32 referrerId) external override whenNotPaused {
        if (usdcAmount < 1e6) revert SAFE_YIELD_INVALID_USDC_AMOUNT();
        if (investor == address(0)) revert SAFE_YIELD_INVALID_USER();
        if (preSaleState != PreSaleState.Live) {
            revert SAFE_YIELD_PRESALE_NOT_LIVE();
        }

        (uint128 safeTokensBought, uint128 referrerUsdcCommission, uint128 referrerSafeTokenCommission) =
            _buyToken(investor, usdcAmount, referrerId);

        emit TokensPurchased(
            investor, usdcAmount, safeTokensBought, referrerUsdcCommission, referrerSafeTokenCommission, referrerId
        );
    }

    /**
     * @dev Set the referrer commission
     * @param _commissionUsdc The referrer commission in USDC
     * @param _commissionSafe The referrer commission in safeTokens
     * referrer commission is not more than 100%
     */
    function setReferrerCommission(uint128 _commissionUsdc, uint128 _commissionSafe) external override onlyOwner {
        if (_commissionUsdc > BPS_MAX || _commissionSafe > BPS_MAX) {
            revert SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
        }
        referrerCommissionUsdcBps = _commissionUsdc;
        referrerCommissionSafeTokenBps = _commissionSafe;

        emit ReferrerCommissionSet(_commissionUsdc, _commissionSafe);
    }

    /**
     * @dev Set the token price
     * @param _price The token price to set
     */
    function setTokenPrice(uint128 _price) external override onlyOwner {
        if (_price == 0) revert SAFE_YIELD_INVALID_TOKEN_PRICE();
        tokenPrice = _price;

        emit TokenPriceSet(_price);
    }

    /**
     * @dev Set the min and max allocations per wallet
     * @param _min The minimum allocation per wallet
     * @param _max The maximum allocation per wallet
     */
    function setAllocations(uint128 _min, uint128 _max) external override onlyOwner {
        if (_min > _max) revert SAFE_YIELD_INVALID_ALLOCATION();
        minAllocationPerWallet = _min;
        maxAllocationPerWallet = _max;

        emit AllocationSet(_min, _max);
    }

    /**
     * @dev Withdraw USDC from the contract
     * @param receiver The receiver of the USDC
     */
    function withdrawUSDC(address receiver, uint256 amount) external override onlyOwner {
        if (amount != 0) usdcToken.transfer(receiver, amount);

        emit UsdcWithdrawn(receiver, amount);
    }

    /**
     * @dev Redeem USDC commission
     * @notice This function can only be called by the referrer
     */
    function redeemUsdcCommission() external override whenNotPaused {
        bytes32 referrerId = keccak256(abi.encodePacked(msg.sender));

        ReferrerInfo storage _referrerInfo = referrerInfo[referrerId];

        uint256 usdcToRedeem = _referrerInfo.usdcVolume;

        _referrerInfo.usdcVolume = 0;

        if (_referrerInfo.referrer != msg.sender) {
            revert SAFE_YIELD_UNKNOWN_REFERRER();
        }

        usdcToken.safeTransfer(msg.sender, usdcToRedeem);

        emit UsdcCommissionRedeemed(msg.sender, uint128(usdcToRedeem));
    }

    /**
     * @dev Create a referrer ID
     * @notice This function can only be called by an investor
     */
    function createReferrerId() external override whenNotPaused returns (bytes32 referrerId) {
        /**
         * @dev check if the referrer has invested
         */
        if (investorAllocations[msg.sender] == 0) {
            revert SAFE_YIELD_ZERO_BALANCE();
        }

        referrerId = keccak256(abi.encodePacked(msg.sender));

        referrerInfo[referrerId].referrer = msg.sender;

        emit ReferrerIdCreated(msg.sender, referrerId);
    }

    /**
     * @dev Claim safe tokens
     * @notice This function can only be called when the presale has ended
     */
    function claimSafeTokens() external override whenNotPaused {
        if (preSaleState != PreSaleState.Ended) {
            revert SAFE_YIELD_PRESALE_NOT_ENDED();
        }

        uint128 safeTokens = safeYieldStaking.getUserStake(msg.sender).stakedSafeTokenAmount;

        if (safeTokens == 0) revert SAFE_YIELD_ZERO_BALANCE();

        investorAllocations[msg.sender] = 0;
        referrerInfo[keccak256(abi.encodePacked(msg.sender))].safeTokenVolume = 0;

        safeYieldStaking.unstake(msg.sender, safeTokens);

        emit SafeTokensClaimed(msg.sender, safeTokens);
    }

    function safeTokensAvailable() public view override returns (uint128) {
        return uint128(PRE_SALE_CAP - totalSold);
    }

    /**
     * @dev calculate the safe tokens to be bought
     * @param usdcAmount The amount of USDC to be used to buy the safe tokens
     * @return safeTokens The amount of safe tokens to be bought
     */
    function calculateSafeTokens(uint128 usdcAmount) public view override returns (uint128) {
        return (usdcAmount * tokenPrice) / USDC_PRECISION;
    }

    /**
     * @dev Get the total safeTokens owed to a user
     * @param user The user to get the total safeTokens owed for
     */
    function getTotalSafeTokensOwed(address user) public view override returns (uint128) {
        bytes32 referrerId = keccak256(abi.encodePacked(user));
        return investorAllocations[user] + referrerInfo[referrerId].safeTokenVolume;
    }

    function _buyToken(address investor, uint128 usdcAmount, bytes32 referrerId)
        internal
        returns (uint128 safeTokensBought, uint128 referrerUsdcCommission, uint128 referrerSafeTokenCommission)
    {
        /**
         *  @dev calculate the safe tokens bought at 1$ per token.
         *  formula: (usdcAmount * tokenPrice) / USDC_PRECISION
         *  example if usdcAmount = 1_000e6 and tokenPrice = 1$ then
         *  safeTokensBought = (1_000e6 * 1e18) / 1e6 = 1_000e18 safe tokens.
         */
        safeTokensBought = calculateSafeTokens(usdcAmount);

        if (safeTokensBought == 0) revert SAFE_YIELD_INVALID_ALLOCATION();

        /**
         * @dev check if the safe tokens bought is less than
         * the min allocation per wallet
         */
        if (safeTokensBought < minAllocationPerWallet) {
            revert SAFE_YIELD_MIN_WALLET_ALLOCATION_EXCEEDED();
        }

        /**
         * @dev check if the total allocation of the investor plus
         * the safe tokens bought is greater than the max allocation per wallet.
         */
        if (investorAllocations[investor] + safeTokensBought > maxAllocationPerWallet) {
            revert SAFE_YIELD_MAX_WALLET_ALLOCATION_EXCEEDED();
        }

        usdcToken.safeTransferFrom(investor, address(this), usdcAmount);

        //referral commissions
        address referrerInvestor;
        if (referrerId != bytes32(0)) {
            ReferrerInfo storage referrer = referrerInfo[referrerId];

            referrerInvestor = referrer.referrer;

            if (referrer.referrer == address(0)) {
                revert SAFE_YIELD_UNKNOWN_REFERRER();
            }

            if (referrer.referrer == investor) {
                revert SAFE_YIELD_REFERRAL_TO_SELF();
            }

            /**
             * @dev calculate the referrer commission
             * in both USDC and SafeToken
             *
             */
            referrerUsdcCommission = (usdcAmount * referrerCommissionUsdcBps) / BPS_MAX;
            referrerSafeTokenCommission = (safeTokensBought * referrerCommissionSafeTokenBps) / BPS_MAX;

            /**
             * @dev check if the total allocation of the referrer plus
             * the referrer safe token commission
             * is greater than the max allocation per wallet.
             */
            // if (
            //     investorAllocations[referrer.referrer] +
            //         referrerSafeTokenCommission >
            //     maxAllocationPerWallet
            // ) revert SAFE_YIELD_REFERRER_MAX_WALLET_ALLOCATION_EXCEEDED();

            referrer.usdcVolume += referrerUsdcCommission;
            referrer.safeTokenVolume += referrerSafeTokenCommission;
        }

        /**
         * @dev check if the total sold tokens plus the safe tokens bought plus
         * the referrer safe token commission is greater than the pre sale cap
         */
        if (totalSold + safeTokensBought + referrerSafeTokenCommission > PRE_SALE_CAP) {
            revert SAFE_YIELD_MAX_SUPPLY_EXCEEDED();
        }

        uint128 totalSafeTokensToMint = safeTokensBought + referrerSafeTokenCommission;

        totalSold += totalSafeTokensToMint;
        investorAllocations[investor] += safeTokensBought;

        /**
         *
         */
        if (referrerInvestor != address(0)) {
            safeToken.mint(address(safeYieldStaking), totalSafeTokensToMint);

            safeYieldStaking.stakeFor(investor, safeTokensBought, referrerInvestor, referrerSafeTokenCommission);
        } else {
            safeToken.mint(address(this), safeTokensBought);
            safeToken.approve(address(safeYieldStaking), safeTokensBought);
            safeYieldStaking.stake(safeTokensBought, investor);
        }
    }
}
