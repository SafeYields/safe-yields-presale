// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.21;
// import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// import {ISafeYieldStaking} from "./interfaces/ISafeYieldStaking.sol";
// import {ISafeYieldPreSale} from "./interfaces/ISafeYieldPreSale.sol";
// import {ISafeToken} from "./interfaces/ISafeToken.sol";

// import {PreSaleState, ReferrerVolume} from "./types/SafeTypes.sol";
// import {console} from "forge-std/Test.sol";

// // Requirements checklist
// //// - [x] The contract should be pausable.
// // - [x] The contract should be ownable.
// //// - [x] The contract should be able to receive USDC safeTokens.
// //// - [x] The contract should be able to receive SafeYield safeTokens.
// //// - [x] The contract should have a max supply of safeTokens.
// //// - [x] The contract should have a min and max allocation per wallet.
// //// - [x] The contract should have a token price.
// //// - [x] The contract should have a referrer commission.
// //// - [x] The contract should have a state.
// //// - [x] The contract should have a function to buy safeTokens.
// //// - [x] The contract should have a function to claim safeTokens.
// //// - [x] The contract should have a function to set the token price.
// //// - [x] The contract should have a function to set the referrer commission.
// // - [x] The contract should have a function to calculate safeTokens.
// // - [x] The contract should have a function to calculate safeTokens available.
// // - [x] The contract should have a function to calculate referrer commission.
// // - [x] The contract take into account the 6 decimal places of USDC.

// //Invariants
// // - [x] The referrer must have invested before referring.
// // - [x] The user must be within the min and max allocation. to buy
// // - [x] The total sold safeTokens must not exceed the max supply.
// // - [x] The user must have enough USDC to buy safeTokens.
// // - [x] The total of a user's safe balance should equal their Referrer volume and investment
// // - [x] Cannot refer ones's self

// // access control
// // state
// // money
// // Referrer

// contract SafeYieldPresale is ISafeYieldPreSale, Pausable, Ownable {
//     using SafeERC20 for IERC20;
//     using SafeERC20 for ISafeToken;

//     /*//////////////////////////////////////////////////////////////
//                      CONSTANTS & IMMUTABLES
//     //////////////////////////////////////////////////////////////*/
//     ISafeYieldStaking public immutable safeYieldStaking;
//     ISafeToken public immutable safeToken;
//     IERC20 public immutable usdcToken;
//     uint128 public immutable maxSupply;
//     uint128 public constant BPS_MAX = 100_00; //100_00 is 100% in this context
//     uint32 public constant USDC_PRECISION = 1e6;
//     uint8 public constant USDC_DECIMALS = 6;

//     /*//////////////////////////////////////////////////////////////
//                             STATE VARIABLES
//     //////////////////////////////////////////////////////////////*/
//     uint128 public totalSold;
//     uint128 public minAllocationPerWallet;
//     uint128 public maxAllocationPerWallet;
//     uint128 public tokenPrice;
//     uint128 public referrerCommissionUsdc;
//     uint128 public referrerCommissionSafeToken;

//     mapping(address userAddress => uint128 safeTokensAllocation)
//         public investments;
//     mapping(bytes32 referrerId => ReferrerVolume referrerVolume)
//         public referrerVolumes;
//     PreSaleState public preSaleState;

//     /*//////////////////////////////////////////////////////////////
//                                  EVENTS
//     //////////////////////////////////////////////////////////////*/
//     event TokensPurchased(
//         address indexed buyer,
//         uint128 usdcAmount,
//         uint128 safeTokens,
//         uint128 referrerCommissionUsdc,
//         uint128 referrerCommissionSafeToken,
//         bytes32 referrerId
//     );
//     event TokensClaimed(address indexed claimer, uint128 tokenAmount);

//     /*//////////////////////////////////////////////////////////////
//                                  ERRORS
//     //////////////////////////////////////////////////////////////*/
//     error SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
//     error SAFE_YIELD_INVALID_ALLOCATION();
//     error SAFE_YIELD_MAX_SUPPLY_EXCEEDED();
//     error SAFE_YIELD_INVALID_TOKEN_PRICE();
//     error SAFE_YIELD_INVALID_MAX_SUPPLY();
//     error SAFE_YIELD_PRESALE_NOT_ENDED();
//     error SAFE_YIELD_UNKNOWN_REFERRER();
//     error SAFE_YIELD_REFERRAL_TO_SELF();
//     error SAFE_YIELD_INVALID_ADDRESS();
//     error SAFE_YIELD_PRESALE_NOT_LIVE();
//     error SAFE_YIELD_INVALID_USER();
//     error SAFE_YIELD_ZERO_BALANCE();

//     modifier IsValidReferrer(address _referrer) {
//         address referrerValid = _retrieveReferrer(_hashReferrer(_referrer));

//         if (referrerValid != _referrer) revert SAFE_YIELD_INVALID_ADDRESS();

//         _;
//     }

//     constructor(
//         address _safeToken,
//         address _usdcToken,
//         address _safeYieldStaking,
//         uint128 _maxSupply,
//         uint128 _minAllocationPerWallet,
//         uint128 _maxAllocationPerWallet,
//         uint128 _tokenPrice,
//         uint128 _referrerCommissionUsdc,
//         uint128 _referrerCommissionSafeToken
//     ) Ownable(msg.sender) {
//         if (_minAllocationPerWallet > _maxAllocationPerWallet)
//             revert SAFE_YIELD_INVALID_ALLOCATION();

//         if (
//             referrerCommissionUsdc > BPS_MAX ||
//             referrerCommissionSafeToken > BPS_MAX
//         ) revert SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();

//         if (_tokenPrice == 0) revert SAFE_YIELD_INVALID_TOKEN_PRICE();
//         if (_maxSupply == 0) revert SAFE_YIELD_MAX_SUPPLY_EXCEEDED();
//         if (_safeToken == address(0) || _usdcToken == address(0))
//             revert SAFE_YIELD_INVALID_ADDRESS();

//         safeToken = ISafeToken(_safeToken);
//         usdcToken = IERC20(_usdcToken);

//         safeYieldStaking = ISafeYieldStaking(_safeYieldStaking);

//         maxSupply = _maxSupply;

//         minAllocationPerWallet = _minAllocationPerWallet;
//         maxAllocationPerWallet = _maxAllocationPerWallet;

//         tokenPrice = _tokenPrice;

//         referrerCommissionUsdc = _referrerCommissionUsdc;
//         referrerCommissionSafeToken = _referrerCommissionSafeToken;

//         preSaleState = PreSaleState.NotStarted;
//     }

//     /**
//      * @dev Buy safeTokens
//      * @param user The user buying the safeTokens
//      * @param usdcAmount The amount of USDC to buy the safeTokens with
//      */
//     function buy(address user, uint128 usdcAmount) external whenNotPaused {
//         if (user == address(0)) revert SAFE_YIELD_INVALID_USER();
//         if (preSaleState != PreSaleState.Live)
//             revert SAFE_YIELD_PRESALE_NOT_LIVE();

//         (uint128 safeTokensAlloc, , ) = _buy(user, usdcAmount, 0);

//         emit TokensPurchased(
//             user,
//             usdcAmount,
//             safeTokensAlloc,
//             0,
//             0,
//             bytes32(0)
//         );
//     }

//     /**
//      * @dev Buy safeTokens with a referrer
//      * @param user The user buying the safeTokens
//      * @param referrerAddress The referrer's address
//      * @param usdcAmount The amount of USDC to buy the safeTokens with
//      */
//     function buyWithReferrer(
//         address user,
//         uint128 usdcAmount,
//         address referrerAddress
//     ) external whenNotPaused IsValidReferrer(referrerAddress) {
//         if (user == address(0)) revert SAFE_YIELD_INVALID_USER();

//         if (preSaleState != PreSaleState.Live)
//             revert SAFE_YIELD_PRESALE_NOT_LIVE();

//         // check if the referrer has invested (a valid referrer)
//         if (investments[referrerAddress] == 0)
//             revert SAFE_YIELD_UNKNOWN_REFERRER();
//         if (referrerAddress == user) revert SAFE_YIELD_REFERRAL_TO_SELF();

//         bytes32 referrerId = _hashReferrer(referrerAddress);

//         (
//             uint128 safeTokensAlloc,
//             uint128 referCommissionSafe,
//             uint128 referrerCommissionUsdc_
//         ) = _buy(user, usdcAmount, referrerId);

//         referrerVolumes[referrerId].usdcVolume += referrerCommissionUsdc_;
//         referrerVolumes[referrerId].safeTokenVolume += referCommissionSafe;

//         emit TokensPurchased(
//             user,
//             usdcAmount,
//             safeTokensAlloc,
//             referrerCommissionUsdc_,
//             referCommissionSafe,
//             bytes32(referrerId)
//         );
//     }

//     /**
//      * @dev Claim safeTokens
//      * @notice This function can only be called when the presale has ended
//      */
//     function claim() external whenNotPaused {
//         if (preSaleState != PreSaleState.Ended) {
//             revert SAFE_YIELD_PRESALE_NOT_ENDED();
//         }
//         uint128 safeTokensToClaim = getTotalSafeTokensOwed(msg.sender);

//         bytes32 referrerId = _hashReferrer(msg.sender);

//         uint128 usdcAmountToClaim = referrerVolumes[referrerId].usdcVolume;

//         if (safeTokensToClaim == 0) {
//             revert SAFE_YIELD_ZERO_BALANCE();
//         }

//         investments[msg.sender] = 0;
//         referrerVolumes[referrerId].usdcVolume = 0;
//         referrerVolumes[referrerId].safeTokenVolume = 0;

//         safeToken.safeTransfer(msg.sender, safeTokensToClaim);

//         if (usdcAmountToClaim != 0) {
//             usdcToken.safeTransfer(msg.sender, usdcAmountToClaim);
//         }

//         emit TokensClaimed(msg.sender, safeTokensToClaim);
//     }

//     /**
//      * @dev Set the token price
//      * @param _price The token price to set
//      */
//     function setTokenPrice(uint128 _price) public onlyOwner {
//         if (_price == 0) revert SAFE_YIELD_INVALID_TOKEN_PRICE();
//         tokenPrice = _price;
//     }

//     /**
//      * @dev Set the referrer commission
//      * @param _commissionUsdc The referrer commission in USDC
//      * @param _commissionSafe The referrer commission in safeTokens
//      * referrer commission is not more than 100%
//      */
//     function setReferrerCommission(
//         uint128 _commissionUsdc,
//         uint128 _commissionSafe
//     ) public onlyOwner {
//         if (_commissionUsdc > BPS_MAX || _commissionSafe > BPS_MAX)
//             revert SAFE_YIELD_INVALID_REFER_COMMISSION_PERCENTAGE();
//         referrerCommissionUsdc = _commissionUsdc;
//         referrerCommissionSafeToken = _commissionSafe;
//     }

//     /**
//      * @dev Deposit safeTokens into the contract
//      * @param amount The amount of safeTokens to deposit
//      * @param owner_ The owner of the safeTokens
//      */
//     function depositSafeTokens(
//         uint128 amount,
//         address owner_
//     ) public onlyOwner {
//         safeToken.safeTransferFrom(owner_, address(this), amount);
//     }

//     /**
//      * @dev Set the min and max allocations per wallet
//      * @param _min The minimum allocation per wallet
//      * @param _max The maximum allocation per wallet
//      */
//     function setAllocations(uint128 _min, uint128 _max) public onlyOwner {
//         if (_min > _max) revert SAFE_YIELD_INVALID_ALLOCATION();
//         minAllocationPerWallet = _min;
//         maxAllocationPerWallet = _max;
//     }

//     /**
//      * @dev Pause the presale
//      * @notice This function can only be called by the owner
//      */
//     function pause() public onlyOwner {
//         _pause();
//     }

//     /**
//      * @dev Unpause the presale
//      * @notice This function can only be called by the owner
//      */
//     function unpause() public onlyOwner {
//         _unpause();
//     }

//     /**
//      * @dev Start the presale
//      * @notice This function can only be called by the owner
//      */
//     function startPresale() public onlyOwner {
//         preSaleState = PreSaleState.Live;
//     }

//     /**
//      * @dev End the presale
//      * @notice This function can only be called by the owner
//      */
//     function endPresale() public onlyOwner {
//         preSaleState = PreSaleState.Ended;
//     }

//     /**
//      * @dev Calculate the safeTokens for a given USDC amount
//      * @param usdcAmount The amount of USDC to calculate the safeTokens for
//      * @return The safeTokens for the given USDC amount
//      */
//     function _calculatesSafeTokens(
//         uint128 usdcAmount
//     ) internal view returns (uint128) {
//         uint128 modifiedPrecision = 1e6;
//         return (usdcAmount * tokenPrice) / modifiedPrecision;
//     }

//     /**
//      * @dev Calculate the safeTokens available for sale
//      * @return The safeTokens available for sale
//      */
//     function calculatesSafeTokensAvailable() public view returns (uint128) {
//         return maxSupply - totalSold;
//     }

//     // /**
//     //  * @dev Calculate the referrer commission
//     //  * @param safeTokens The amount of safeTokens to calculate the referrer commission for
//     //  * @return The referrer commission
//     //  */
//     // function calculateReferrerCommissionSafe(
//     //     uint128 safeTokens
//     // ) public view returns (uint128) {
//     //     if (safeTokens == 0) return 0;
//     //     return (safeTokens * referrerCommissionSafeToken) / BPS_MAX;
//     // }

//     // function calculateReferrerCommissionUsdc(
//     //     uint128 usdcAmount
//     // ) public view returns (uint128) {
//     //     if (usdcAmount == 0) return 0;
//     //     return (usdcAmount * referrerCommissionUsdc) / BPS_MAX;
//     // }

//     /**
//      * @dev Get the total safeTokens owed to a user
//      * @param user The user to get the total safeTokens owed for
//      */
//     function getTotalSafeTokensOwed(
//         address user
//     ) public view returns (uint128) {
//         return
//             investments[user] +
//             referrerVolumes[_hashReferrer(user)].safeTokenVolume;
//     }

//     ///!@q are withdrawals allowed before the presale ends? / all safeTokens are sold?
//     /**
//      * @dev Withdraw USDC from the contract
//      * @param receiver The receiver of the USDC
//      */
//     function withdrawUSDC(address receiver) public onlyOwner {
//         uint256 balance = usdcToken.balanceOf(address(this));
//         usdcToken.transfer(receiver, balance);
//     }

//     /**
//      * @dev Buy safeTokens
//      * @param user The user buying the safeTokens
//      * @param usdcAmount The amount of USDC to buy the safeTokens with
//      * @param referrerId The referrer id
//      * @return safeTokensAlloc The safeTokens allocated
//      * @return referCommissionSafe The referrer commission in safeTokens
//      * @return referrerCommissionUsdc_ The referrer commission in USDC
//      */
//     function _buy(
//         address user,
//         uint128 usdcAmount,
//         bytes32 referrerId
//     )
//         internal
//         returns (
//             uint128 safeTokensAlloc,
//             uint128 referCommissionSafe,
//             uint128 referrerCommissionUsdc_
//         )
//     {
//         safeTokensAlloc = (usdcAmount * tokenPrice) / USDC_PRECISION;

//         console.log("safeTokensAlloc", safeTokensAlloc);

//         if (safeTokensAlloc == 0) revert SAFE_YIELD_INVALID_ALLOCATION();

//         if (referrerId != 0) {
//             referCommissionSafe =
//                 (safeTokensAlloc * referrerCommissionSafeToken) /
//                 BPS_MAX;

//             referrerCommissionUsdc_ =
//                 (usdcAmount * referrerCommissionUsdc) /
//                 BPS_MAX;
//         }

//         // check that the max supply is not exceeded
//         if (totalSold + safeTokensAlloc + referCommissionSafe > maxSupply) {
//             revert SAFE_YIELD_MAX_SUPPLY_EXCEEDED();
//         }

//         usdcToken.safeTransferFrom(user, address(this), usdcAmount);

//         //@audit assumption  - maxAllocationPerWallet includes the referrer commission

//         uint128 currentInvestment = investments[user];
//         uint128 potentialSafeTokensAlloc = currentInvestment +
//             safeTokensAlloc +
//             referrerVolumes[referrerId].safeTokenVolume;

//         if (
//             potentialSafeTokensAlloc < minAllocationPerWallet ||
//             potentialSafeTokensAlloc > maxAllocationPerWallet
//         ) {
//             revert SAFE_YIELD_INVALID_ALLOCATION();
//         }

//         investments[user] += safeTokensAlloc;

//         totalSold += safeTokensAlloc + referCommissionSafe;

//         safeToken.mint(address(this), safeTokensAlloc);

//         _autoStake(safeTokensAlloc, user);
//     }

//     /**
//      * @dev hash the referrer address
//      * @param referrer The referrer address to hash
//      */
//     function _hashReferrer(address referrer) public pure returns (bytes32) {
//         return bytes32(abi.encodePacked(referrer));
//     }

//     /**
//      * @dev retrieve the referrer address
//      * @param referrerId The referrer id to retrieve
//      */
//     function _retrieveReferrer(
//         bytes32 referrerId
//     ) private pure returns (address) {
//         uint256 tempData = uint256(referrerId); // Convert bytes32 to uint256
//         uint160 extractedAddress = uint160(tempData >> 96); // Remove padding zeros
//         return address(extractedAddress);
//     }

//     function _autoStake(uint128 amount, address user) private {
//         //stake the safeTokens
//         uint256 allowance = safeToken.allowance(
//             address(this),
//             address(safeYieldStaking)
//         );
//         if (allowance < amount) {
//             safeToken.approve(address(safeYieldStaking), amount);
//         }
//         safeYieldStaking.stake(amount, user);
//     }
// }

// ///!@ possible DOS is the tokens left are enough for purchase but not enough to cover referrer volume

// //!@q is there a cap on referrer volume per wallet
// //!@q does the maxAllocationPerWallet include the referrer commission?
// //!@ who bears the referrers commission the protocol or the user buying
// //!@ should withdrawals of usdc be matched with a deposit of  safeTokens for claiming admin side
