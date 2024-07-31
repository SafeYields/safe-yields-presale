// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { PreSaleState, ReferrerInfo, ReferrerRecipient } from "./types/SafeTypes.sol";

contract SafeYieldPresale is ISafeYieldPreSale, Pausable, Ownable2Step {
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
    address public protocolMultisig;
    uint128 public totalSold;
    uint128 public minAllocationPerWallet;
    uint128 public maxAllocationPerWallet;
    /// @dev the price of SAY tokens to 18 decimal precision
    uint128 public tokenPrice;
    uint128 public referrerCommissionUsdcBps;
    uint128 public referrerCommissionSafeTokenBps;
    uint128 public totalRedeemableReferrerUsdc;
    uint128 public totalUsdcRaised; //total usdc raised in the presale minus the referrer commissions

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
        bytes32 referrerIdInput,
        bytes32 buyerReferrerId
    );
    event ReferrerCommissionBpsSet(
        uint128 indexed referrerCommissionUsdcBps, uint128 indexed referrerCommissionSafeTokenBps
    );
    event UsdcCommissionRedeemed(address indexed referrer, uint128 indexed usdcAmount);
    event SafeTokensClaimed(address indexed investor, uint128 indexed safeTokens);
    event UsdcWithdrawn(address indexed receiver, uint256 indexed amount);
    event TokenPriceSet(uint128 indexed tokenPrice);
    event PreSaleStarted(PreSaleState indexed currentState);
    event PreSaleEnded(PreSaleState indexed currentState);
    event SafeTokensRecovered(uint256 indexed amount);
    event ProtocolMultisigSet(address indexed protocolMultisig);
    event PreSaleAllocationsMinted(uint256 indexed amount);
    event AllocationsPerWalletSet(uint128 indexed minAllocationPerWallet, uint128 indexed maxAllocationPerWallet);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SYPS__INVALID_REFER_COMMISSION_PERCENTAGE();
    error SYPS__BELOW_MIN_ALLOCATION();
    error SYPS__NO_MORE_TOKENS_LEFT();
    error SYPS__INVALID_AMOUNT();
    error SYPS__INVALID_TOKEN_PRICE();
    error SYPS__INVALID_ALLOCATION();
    error SYPS__PRESALE_NOT_ENDED();
    error SYPS__UNKNOWN_REFERRER();
    error SYPS__REFERRAL_TO_SELF();
    error SYPS__PRESALE_NOT_LIVE();
    error SYPS__INVALID_ADDRESS();
    error SYPS__ZERO_BALANCE();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier preSaleEnded() {
        if (currentPreSaleState != PreSaleState.Ended) revert SYPS__PRESALE_NOT_ENDED();
        _;
    }

    modifier isValidInvestor(address caller) {
        /**
         * @dev check if the referrer has invested
         */
        if (investorAllocations[caller] == 0) revert SYPS__ZERO_BALANCE();

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
        address _protocolMultisig
    ) Ownable(msg.sender) {
        if (_minAllocationPerWallet > _maxAllocationPerWallet) {
            revert SYPS__INVALID_ALLOCATION();
        }

        if (_referrerCommissionUsdcBps >= BPS_MAX || _referrerCommissionSafeTokenBps >= BPS_MAX) {
            revert SYPS__INVALID_REFER_COMMISSION_PERCENTAGE();
        }

        if (_tokenPrice == 0) revert SYPS__INVALID_TOKEN_PRICE();

        if (
            _safeToken == address(0) || _usdcToken == address(0) || _safeYieldStaking == address(0)
                || _protocolMultisig == address(0)
        ) {
            revert SYPS__INVALID_ADDRESS();
        }

        protocolMultisig = _protocolMultisig;

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
     * @param referrerIdInput the referrer id of a referrer
     */
    function deposit(uint128 usdcAmount, bytes32 referrerIdInput) external override whenNotPaused {
        if (currentPreSaleState != PreSaleState.Live) revert SYPS__PRESALE_NOT_LIVE();

        (
            uint128 safeTokensBought,
            uint128 referrerUsdcCommission,
            uint128 referrerSafeTokenCommission,
            uint128 usdcPurchaseAmount,
            bytes32 buyerReferrerId
        ) = _buyToken(_msgSender(), usdcAmount, referrerIdInput);

        emit TokensPurchased(
            _msgSender(),
            usdcPurchaseAmount,
            safeTokensBought,
            referrerUsdcCommission,
            referrerSafeTokenCommission,
            referrerIdInput,
            buyerReferrerId
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
            revert SYPS__INVALID_REFER_COMMISSION_PERCENTAGE();
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
        if (_price == 0) revert SYPS__INVALID_TOKEN_PRICE();

        tokenPrice = _price;

        emit TokenPriceSet(_price);
    }

    /**
     * @dev Set the min and max allocations per wallet
     * @param _min The minimum allocation per wallet
     * @param _max The maximum allocation per wallet
     */
    function setAllocationsPerWallet(uint128 _min, uint128 _max) external override onlyOwner {
        if (_min >= _max) revert SYPS__INVALID_ALLOCATION();

        minAllocationPerWallet = _min;
        maxAllocationPerWallet = _max;

        emit AllocationsPerWalletSet(_min, _max);
    }

    function setProtocolMultisig(address _protocolMultisig) external override onlyOwner {
        if (_protocolMultisig == address(0)) revert SYPS__INVALID_ADDRESS();

        protocolMultisig = _protocolMultisig;

        emit ProtocolMultisigSet(_protocolMultisig);
    }

    /**
     * @dev Recover tokens sent to the contract
     * @param amount The amount of tokens to recover
     */
    function recoverSafeTokens(uint256 amount) external onlyOwner preSaleEnded {
        if (amount == 0) revert SYPS__INVALID_AMOUNT();

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

        if (_referrerInfo.referrer != msg.sender) revert SYPS__UNKNOWN_REFERRER();

        usdcToken.safeTransfer(msg.sender, usdcToRedeem);

        emit UsdcCommissionRedeemed(msg.sender, uint128(usdcToRedeem));
    }

    function getReferrerID() public view override isValidInvestor(msg.sender) returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender));
    }

    /**
     * @dev Claim safe tokens
     * @notice This function can only be called when the presale has ended
     */
    function claimSafeTokens() external override whenNotPaused preSaleEnded {
        uint128 safeTokens = safeYieldStaking.getUserStake(msg.sender).stakeAmount;
        if (safeTokens == 0) revert SYPS__ZERO_BALANCE();

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
    function calculateSafeTokens(uint256 usdcAmount) public view override returns (uint128) {
        return uint128((usdcAmount * 1e30) / tokenPrice);
    }

    /**
     * @dev Get the total safeTokens owed to a user
     * @param user The user to get the total safeTokens owed for
     */
    function getTotalSafeTokensOwed(address user) public view override returns (uint128) {
        bytes32 referrerId = keccak256(abi.encodePacked(user));
        return investorAllocations[user] + referrerInfo[referrerId].safeTokenVolume;
    }

    function _buyToken(address investor, uint128 usdcAmount, bytes32 referrerIdInput)
        internal
        returns (
            uint128 safeTokensBought,
            uint128 referrerUsdcCommission,
            uint128 referrerSafeTokenCommission,
            uint128 usdcPurchaseAmount,
            bytes32 buyerReferrerId
        )
    {
        usdcToken.safeTransferFrom(investor, address(this), usdcAmount);

        /**
         *  @dev calculate the safe tokens bought at 1$ per token.
         *  formula: (usdcAmount * tokenPrice) / USDC_PRECISION
         *  example if usdcAmount = 1_000e6 and tokenPrice = 1$ then
         *  safeTokensBought = (1_000e6 * 1e30) / 1e18 = 1_000e18 safe tokens.
         */
        safeTokensBought = calculateSafeTokens(usdcAmount);

        /// @dev check if the safe tokens bought is less than the minimum allocation per wallet.
        if (safeTokensBought < minAllocationPerWallet) revert SYPS__BELOW_MIN_ALLOCATION();

        uint128 safeTokensAvailableForPurchase = safeTokensAvailable();

        uint128 usdcToRefund;

        if (safeTokensAvailableForPurchase == 0) revert SYPS__NO_MORE_TOKENS_LEFT();

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

            if (referrerIdInput != bytes32(0)) {
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
                 * round up in favor for the buyer over the referrer
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

            //the usdc decimals
            usdcToRefund = usdcAmount
                - SafeCast.toUint128((safeTokensBought.mulDiv(USDC_PRECISION, tokenPrice, Math.Rounding.Ceil)));
        }

        ///@dev actual usdc amount used for purchase.
        usdcAmount -= usdcToRefund;

        /// @dev used to event purposes.
        usdcPurchaseAmount = usdcAmount;

        /// @dev refund the remaining usdc to the user
        if (usdcToRefund != 0) usdcToken.safeTransfer(investor, usdcToRefund);

        ///@notice referral commissions
        address referrerInvestor;
        if (referrerIdInput != bytes32(0)) {
            ReferrerInfo storage _referrerInfo = referrerInfo[referrerIdInput];

            referrerInvestor = _referrerInfo.referrer;

            if (referrerInvestor == address(0)) revert SYPS__UNKNOWN_REFERRER();

            if (referrerInvestor == investor) revert SYPS__REFERRAL_TO_SELF();

            referrerUsdcCommission =
                SafeCast.toUint128(usdcAmount.mulDiv(referrerCommissionUsdcBps, BPS_MAX, Math.Rounding.Floor));

            referrerSafeTokenCommission = SafeCast.toUint128(
                safeTokensBought.mulDiv(referrerCommissionSafeTokenBps, BPS_MAX, Math.Rounding.Floor)
            );
            /**
             * @dev calculate the referrer commission in both USDC and SafeToken
             * @notice To prevent rounding issues if user is buying remaining safe tokens, we
             * subtract instead re-calculating the commissions
             */
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
                    referrerIndex[referrerInvestor][investor] = uint128(referrerRecipients[referrerInvestor].length);

                    referrerRecipients[referrerInvestor].push(
                        ReferrerRecipient({ referrerRecipient: investor, usdcAmountInvested: usdcAmount })
                    );
                } else {
                    referrerRecipients[referrerInvestor][referrerIndex[referrerInvestor][investor]].usdcAmountInvested
                    += usdcAmount;
                }
            }
        }

        /**
         * @dev update the usdc raised
         * This is the total amount of USDC raised in the presale minus the referrer commission.
         */
        uint128 amountRaised = (usdcAmount - referrerUsdcCommission);

        totalUsdcRaised += amountRaised;

        /**
         * @dev transfer the USDC raised to the protocol multisig
         */
        usdcToken.transfer(protocolMultisig, amountRaised);

        investorAllocations[investor] += safeTokensBought;

        uint128 totalSafeTokensToStake = safeTokensBought + referrerSafeTokenCommission;

        totalSold += totalSafeTokensToStake;

        //create refID.
        buyerReferrerId = getReferrerID();
        referrerInfo[buyerReferrerId].referrer = msg.sender;

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

    function mintPreSaleAllocation() external override onlyOwner {
        safeToken.mint(PRE_SALE_CAP);

        emit PreSaleAllocationsMinted(PRE_SALE_CAP);
    }
}
