// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { PreSaleState, ReferrerInfo, ReferrerRecipient } from "./types/SafeTypes.sol";
//import { console } from "forge-std/Test.sol";

contract SafeYieldPresale is ISafeYieldPreSale, Pausable, Ownable {
    using Math for uint128;
    using Math for uint256;

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

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    PreSaleState public currentPreSaleState;
    uint128 public totalSold;
    uint128 public minAllocationPerWallet;
    uint128 public maxAllocationPerWallet;
    uint128 public tokenPrice;
    uint128 public referrerCommissionUsdcBps;
    uint128 public referrerCommissionSafeTokenBps;
    uint128 public totalRedeemableReferrerUsdc;
    address public protocolAdmin;
    uint128 public totalUsdcRaised; //total usdc raised in the presale minus the referrer commission
    uint128 public totalUsdcToWithdraw; //To be reset after withdrawal
    mapping(address userAddress => uint128 safeTokensAllocation) public investorAllocations;
    mapping(bytes32 referrerId => ReferrerInfo referrerInfo) public referrerInfo;
    mapping(address investor => mapping(address referrer => uint128 index)) public referrerIndex;
    mapping(address referrer => ReferrerRecipient[]) public referrerRecipients;
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
    event ReferrerCommissionBpsSet(
        uint128 indexed referrerCommissionUsdcBps, uint128 indexed referrerCommissionSafeTokenBps
    );
    event ReferrerIdCreated(address indexed referrer, bytes32 indexed referrerId);
    event UsdcCommissionRedeemed(address indexed referrer, uint128 indexed usdcAmount);
    event SafeTokensClaimed(address indexed investor, uint128 indexed safeTokens);
    event UsdcWithdrawn(address indexed receiver, uint256 indexed amount);
    event TokenPriceSet(uint128 indexed tokenPrice);
    event PreSaleStarted(PreSaleState indexed currentState);
    event PreSaleEnded(PreSaleState indexed currentState);
    event SafeTokensRecovered(uint256 indexed amount);
    event AllocationsPerWalletSet(uint128 indexed minAllocationPerWallet, uint128 indexed maxAllocationPerWallet);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SAFE_YIELD_REFERRER_MAX_WALLET_ALLOCATION_EXCEEDED();
    error SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
    error SAFE_YIELD_MAX_WALLET_ALLOCATION_EXCEEDED();
    error SAFE_YIELD_BELOW_MIN_ALLOCATION();
    error SAFE_YIELD_NO_MORE_TOKENS_LEFT();
    error SAFE_YIELD_MAX_SUPPLY_EXCEEDED();
    error SAFE_YIELD_INVALID_USDC_AMOUNT();
    error SAFE_YIELD_INVALID_AMOUNT();
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

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier preSaleNotEnded() {
        if (currentPreSaleState != PreSaleState.Ended) revert SAFE_YIELD_PRESALE_NOT_ENDED();
        _;
    }

    constructor(
        address _safeToken,
        address _usdcToken,
        address _safeYieldStaking,
        uint128 _minAllocationPerWallet,
        uint128 _maxAllocationPerWallet,
        uint128 _tokenPrice,
        uint128 _referrerCommissionUsdcBps,
        uint128 _referrerCommissionSafeTokenBps,
        address _protocolAdmin
    ) Ownable(_protocolAdmin) {
        if (_minAllocationPerWallet > _maxAllocationPerWallet) {
            revert SAFE_YIELD_INVALID_ALLOCATION();
        }

        if (_referrerCommissionUsdcBps >= BPS_MAX || _referrerCommissionSafeTokenBps >= BPS_MAX) {
            revert SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
        }

        if (_tokenPrice == 0) revert SAFE_YIELD_INVALID_TOKEN_PRICE();
        if (_safeToken == address(0) || _usdcToken == address(0) || _safeYieldStaking == address(0)) {
            revert SAFE_YIELD_INVALID_ADDRESS();
        }

        safeToken = ISafeToken(_safeToken);
        usdcToken = IERC20(_usdcToken);

        safeYieldStaking = ISafeYieldStaking(_safeYieldStaking);

        minAllocationPerWallet = _minAllocationPerWallet;
        maxAllocationPerWallet = _maxAllocationPerWallet;

        tokenPrice = _tokenPrice;

        referrerCommissionUsdcBps = _referrerCommissionUsdcBps;
        referrerCommissionSafeTokenBps = _referrerCommissionSafeTokenBps;

        currentPreSaleState = PreSaleState.NotStarted;
    }

    /**
     * @dev Pause the presale
     * @notice This function can only be called by the owner()
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the presale
     * @notice This function can only be called by the owner()
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @dev Start the presale
     * @notice This function can only be called by the owner()
     */
    function startPresale() external override onlyOwner {
        currentPreSaleState = PreSaleState.Live;
        emit PreSaleStarted(currentPreSaleState);
    }

    /**
     * @dev End the presale
     * @notice This function can only be called by the owner()
     */
    function endPresale() external override onlyOwner {
        currentPreSaleState = PreSaleState.Ended;
        emit PreSaleEnded(currentPreSaleState);
    }

    /**
     * @dev Buy safe tokens with USDC
     * @param usdcAmount the amount of USDC to be used to buy the safe tokens
     * @param referrerId the referrer id of a referrer
     */
    function deposit(uint128 usdcAmount, bytes32 referrerId) external override whenNotPaused {
        if (currentPreSaleState != PreSaleState.Live) revert SAFE_YIELD_PRESALE_NOT_LIVE();

        (
            uint128 safeTokensBought,
            uint128 referrerUsdcCommission,
            uint128 referrerSafeTokenCommission,
            uint128 usdcPurchaseAmount
        ) = _buyToken(_msgSender(), usdcAmount, referrerId);

        emit TokensPurchased(
            _msgSender(),
            usdcPurchaseAmount,
            safeTokensBought,
            referrerUsdcCommission,
            referrerSafeTokenCommission,
            referrerId
        );
    }

    /**
     * @dev Set the referrer commission
     * @param _commissionUsdcBps The referrer commission in USDC
     * @param _commissionSafeBps The referrer commission in safeTokens
     * referrer commission is not more than 100%
     */
    function setReferrerCommissionBps(uint128 _commissionUsdcBps, uint128 _commissionSafeBps)
        external
        override
        onlyOwner
    {
        if (_commissionUsdcBps >= BPS_MAX || _commissionSafeBps >= BPS_MAX) {
            revert SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
        }

        referrerCommissionUsdcBps = _commissionUsdcBps;
        referrerCommissionSafeTokenBps = _commissionSafeBps;

        emit ReferrerCommissionBpsSet(_commissionUsdcBps, _commissionSafeBps);
    }

    /**
     * @dev Set the token price
     * @param _price The token price to set with 18 decimal of precision
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
    function setAllocationsPerWallet(uint128 _min, uint128 _max) external override onlyOwner {
        if (_min >= _max) revert SAFE_YIELD_INVALID_ALLOCATION();

        minAllocationPerWallet = _min;
        maxAllocationPerWallet = _max;

        emit AllocationsPerWalletSet(_min, _max);
    }

    /**
     * @dev Withdraw USDC from the contract
     */
    function withdrawUSDC() external override onlyOwner {
        uint128 amountToWithdraw = totalUsdcToWithdraw;

        totalUsdcToWithdraw = 0;

        if (amountToWithdraw == 0) return;

        usdcToken.safeTransfer(owner(), amountToWithdraw);

        emit UsdcWithdrawn(owner(), amountToWithdraw);
    }

    /**
     * @dev Recover tokens sent to the contract
     * @param amount The amount of tokens to recover
     */
    function recoverSafeTokens(uint256 amount) external onlyOwner preSaleNotEnded {
        if (amount == 0) revert SAFE_YIELD_INVALID_AMOUNT();

        safeToken.transfer(owner(), amount);

        emit SafeTokensRecovered(amount);
    }

    /**
     * @dev Redeem USDC commission
     * @notice This function can only be called by the referrer
     */
    function redeemUsdcCommission() external override whenNotPaused {
        bytes32 referrerId = keccak256(abi.encodePacked(msg.sender));

        ReferrerInfo storage _referrerInfo = referrerInfo[referrerId];

        uint256 usdcToRedeem = _referrerInfo.usdcVolume;

        totalRedeemableReferrerUsdc -= uint128(usdcToRedeem);

        _referrerInfo.usdcVolume = 0;

        if (_referrerInfo.referrer != msg.sender) revert SAFE_YIELD_UNKNOWN_REFERRER();

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
        if (investorAllocations[msg.sender] == 0) revert SAFE_YIELD_ZERO_BALANCE();

        referrerId = keccak256(abi.encodePacked(msg.sender));

        referrerInfo[referrerId].referrer = msg.sender;

        emit ReferrerIdCreated(msg.sender, referrerId);
    }

    /**
     * @dev Claim safe tokens
     * @notice This function can only be called when the presale has ended
     */
    function claimSafeTokens() external override whenNotPaused preSaleNotEnded {
        uint128 safeTokens = safeYieldStaking.getUserStake(msg.sender).stakeAmount;

        if (safeTokens == 0) revert SAFE_YIELD_ZERO_BALANCE();

        investorAllocations[msg.sender] = 0;

        referrerInfo[keccak256(abi.encodePacked(msg.sender))].safeTokenVolume = 0;

        safeYieldStaking.unStakeFor(msg.sender, safeTokens);

        emit SafeTokensClaimed(msg.sender, safeTokens);
    }

    function safeTokensAvailable() public view override returns (uint128) {
        return SafeCast.toUint128(PRE_SALE_CAP - totalSold);
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
        returns (
            uint128 safeTokensBought,
            uint128 referrerUsdcCommission,
            uint128 referrerSafeTokenCommission,
            uint128 usdcPurchaseAmount
        )
    {
        usdcToken.safeTransferFrom(investor, address(this), usdcAmount);

        /**
         *  @dev calculate the safe tokens bought at 1$ per token.
         *  formula: (usdcAmount * tokenPrice) / USDC_PRECISION
         *  example if usdcAmount = 1_000e6 and tokenPrice = 1$ then
         *  safeTokensBought = (1_000e6 * 1e18) / 1e6 = 1_000e18 safe tokens.
         */
        safeTokensBought = calculateSafeTokens(usdcAmount);

        /// @dev check if the safe tokens bought is less than the minimum allocation per wallet.
        if (safeTokensBought < minAllocationPerWallet) revert SAFE_YIELD_BELOW_MIN_ALLOCATION();

        uint128 safeTokensAvailableForPurchase = safeTokensAvailable();

        uint128 usdcToRefund;

        if (safeTokensAvailableForPurchase == 0) revert SAFE_YIELD_NO_MORE_TOKENS_LEFT();

        //!note keep??
        //uint128 safeTokensToBuy = safeTokensBought;

        if (safeTokensBought >= safeTokensAvailableForPurchase) {
            safeTokensBought = safeTokensAvailableForPurchase;

            /**
             * @dev calculate the remaining usdc to be refunded to the investor
             * say usdAmount is 110_000
             * say safeTokensBought is 99_000e18
             * say tokenPrice is 1e18
             * usdcToRefund = 110_000e6 - (99_000e18 * 1e6) / 1e18 = 110_000e6 - 99_000e6 = 11_000e6
             */
            uint128 valueOfAvailableTokens =
                SafeCast.toUint128((safeTokensBought.mulDiv(USDC_PRECISION, tokenPrice, Math.Rounding.Ceil)));

            usdcToRefund = usdcAmount - valueOfAvailableTokens;

            if (referrerId != bytes32(0)) {
                /**
                 * @dev say referrerCommissionUsdcBps is 5% (500)
                 * totalShareBps = 10_000 + 500 = 10_500
                 */
                uint128 totalShareBps = BPS_MAX + referrerCommissionSafeTokenBps;

                /**
                 * @dev say safeTokensAvailableForPurchase is 500
                 * buyer wants 600 and has a referrer who gets 10% of the buyer's purchase from protocol
                 * we're going to split 500 tokens between the buyer and the referrer allowing 10% of the buyer's purchase to be available for the referrer
                 * 100% + 10% = 110%  = 500 tokens
                 * proportional amount for the buyer = 500 * 100 / 110 = 454.545454545454545454
                 * proportional amount for the referrer = 500 - 454.545454545454545454 = 45.454545454545454545
                 */
                safeTokensBought =
                    SafeCast.toUint128(safeTokensBought.mulDiv(BPS_MAX, totalShareBps, Math.Rounding.Ceil));
            }
        }

        /**
         * @dev check if the total allocation of the investor plus
         * the safe tokens bought is greater than the max allocation per wallet.
         */
        if (investorAllocations[investor] + safeTokensBought > maxAllocationPerWallet) {
            safeTokensBought = maxAllocationPerWallet - investorAllocations[investor];

            usdcToRefund = usdcAmount
                - SafeCast.toUint128((safeTokensBought.mulDiv(USDC_PRECISION, tokenPrice, Math.Rounding.Ceil)));
        }

        ///@dev actual usdc amount used for purchase.
        usdcAmount -= usdcToRefund;

        /// @dev used to event purposes.
        usdcPurchaseAmount = usdcAmount;

        /// @dev refund the remaining usdc to the user
        usdcToken.safeTransfer(investor, usdcToRefund);

        ///@notice referral commissions
        address referrerInvestor;
        //!note move to internal function??
        if (referrerId != bytes32(0)) {
            ReferrerInfo storage _referrerInfo = referrerInfo[referrerId];

            referrerInvestor = _referrerInfo.referrer;

            if (referrerInvestor == address(0)) revert SAFE_YIELD_UNKNOWN_REFERRER();

            if (referrerInvestor == investor) revert SAFE_YIELD_REFERRAL_TO_SELF();

            /**
             * @dev calculate the referrer commission in both USDC and SafeToken
             * @notice To prevent rounding issues if user is buying remaining safe tokens, we
             * subtract instead re-calculating the commissions
             */
            referrerUsdcCommission =
                SafeCast.toUint128(usdcAmount.mulDiv(referrerCommissionUsdcBps, BPS_MAX, Math.Rounding.Floor));

            referrerSafeTokenCommission = SafeCast.toUint128(
                safeTokensBought.mulDiv(referrerCommissionSafeTokenBps, BPS_MAX, Math.Rounding.Floor)
            );

            if (safeTokensBought + referrerSafeTokenCommission > safeTokensAvailableForPurchase) {
                referrerSafeTokenCommission = safeTokensAvailableForPurchase - safeTokensBought;
            }

            totalRedeemableReferrerUsdc += referrerUsdcCommission;

            _referrerInfo.usdcVolume += referrerUsdcCommission;
            _referrerInfo.safeTokenVolume += referrerSafeTokenCommission;

            /**
             * @dev only add a new referrer if it doesn't exist, if yes
             * update the invested usdc.
             */
            if (referrerRecipients[referrerInvestor].length == 0) {
                referrerRecipients[referrerInvestor].push(
                    ReferrerRecipient({ referrerRecipient: investor, usdcAmountInvested: usdcAmount })
                );
            } else {
                if (
                    referrerRecipients[referrerInvestor][referrerIndex[referrerInvestor][investor]].referrerRecipient
                        != investor
                ) {
                    referrerRecipients[referrerInvestor].push(
                        ReferrerRecipient({ referrerRecipient: investor, usdcAmountInvested: usdcAmount })
                    );
                    referrerIndex[referrerInvestor][investor] = uint128(referrerRecipients[referrerInvestor].length) - 1;
                } else {
                    referrerRecipients[referrerInvestor][referrerIndex[referrerInvestor][investor]].usdcAmountInvested
                    += usdcAmount;
                }
            }
        }

        /**
         * @dev update the total usdc raised
         * This is the total amount of USDC raised in the presale minus the referrer commission.
         */
        uint128 amountRaised = (usdcAmount - referrerUsdcCommission);

        totalUsdcRaised += amountRaised;

        totalUsdcToWithdraw += amountRaised;

        investorAllocations[investor] += safeTokensBought;

        uint128 totalSafeTokensToStake = safeTokensBought + referrerSafeTokenCommission;

        totalSold += totalSafeTokensToStake;

        safeToken.approve(address(safeYieldStaking), totalSafeTokensToStake);

        /**
         * @dev check if the referrer is not address(0)
         * then stake the safe tokens bought for both investor and the referrer
         * else stake the safe tokens bought for the investor only.
         */
        if (referrerInvestor != address(0)) {
            safeYieldStaking.autoStakeForBothReferrerAndRecipient(
                investor, safeTokensBought, referrerInvestor, referrerSafeTokenCommission
            );
        } else {
            safeYieldStaking.stakeFor(investor, totalSafeTokensToStake);
        }
    }

    function mintAllAllocations() external override onlyOwner {
        safeToken.mint(PRE_SALE_CAP);
    }
}
