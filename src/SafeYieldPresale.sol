pragma solidity "0.8.21";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Requirements checklist
//// - [x] The contract should be pausable.
// - [x] The contract should be ownable.
//// - [x] The contract should be able to receive USDC safeTokens.
//// - [x] The contract should be able to receive SafeYield safeTokens.
//// - [x] The contract should have a max supply of safeTokens.
//// - [x] The contract should have a min and max allocation per wallet.
//// - [x] The contract should have a token price.
//// - [x] The contract should have a referer commission.
//// - [x] The contract should have a state.
//// - [x] The contract should have a function to buy safeTokens.
//// - [x] The contract should have a function to claim safeTokens.
//// - [x] The contract should have a function to set the token price.
//// - [x] The contract should have a function to set the referer commission.
// - [x] The contract should have a function to calculate safeTokens.
// - [x] The contract should have a function to calculate safeTokens available.
// - [x] The contract should have a function to calculate referer commission.
// - [x] The contract take into account the 6 decimal places of USDC.

//Invariants
// - [x] The referer must have invested before referring.
// - [x] The user must be within the min and max allocation. to buy
// - [x] The total sold safeTokens must not exceed the max supply.
// - [x] The user must have enough USDC to buy safeTokens.
// - [x] The total of a user's safe balance should equal their referer volume and investment
// - [x] Cannot refer ones's self

// access control
// state
// money
// referer

contract SafeYieldPresale is Pausable, Ownable {
    using SafeERC20 for IERC20;

    uint128 public constant PRECISION = 1e18;
    uint128 public constant USDC_DECIMALS = 6;

    IERC20 public immutable safeToken;
    IERC20 public immutable usdcToken;
    uint128 public immutable maxSupply;

    enum PresaleState {
        NotStarted,
        Live,
        Ended
    }

    uint128 public totalSold;
    uint128 public minAllocationPerWallet;
    uint128 public maxAllocationPerWallet;
    uint128 public tokenPrice;
    uint128 public refererCommission;

    PresaleState public state;

    mapping(address userAddress => uint128 safeTokensAllocation)
        public investments;
    mapping(bytes32 refererId => uint128 refererVolume) public refererVolume;

    event TokensPurchased(
        address indexed buyer,
        uint128 usdcAmount,
        uint128 safeTokens,
        uint128 refererCommission,
        bytes32 refererId
    );
    event TokensClaimed(address indexed claimer, uint128 tokenAmount);

    error UnknownReferer();
    error InvalidAllocation();
    error MaxSupplyExceeded();
    error PresaleNotLive();
    error PresaleNotEnded();
    error ReferalToSelf();

    constructor(
        address _safeToken,
        address _usdcToken,
        uint128 _maxSupply,
        uint128 _minAllocationPerWallet,
        uint128 _maxAllocationPerWallet,
        uint128 _tokenPrice,
        uint128 _refererCommission
    ) Ownable(msg.sender) {
        safeToken = IERC20(_safeToken);
        usdcToken = IERC20(_usdcToken);
        maxSupply = _maxSupply;
        minAllocationPerWallet = _minAllocationPerWallet;
        maxAllocationPerWallet = _maxAllocationPerWallet;
        tokenPrice = _tokenPrice;
        refererCommission = _refererCommission;
        state = PresaleState.NotStarted;
    }

    /**
     * @dev Buy safeTokens
     * @param user The user buying the safeTokens
     * @param usdcAmount The amount of USDC to buy the safeTokens with
     */
    function buy(address user, uint128 usdcAmount) external whenNotPaused {
        if (state != PresaleState.Live) revert PresaleNotLive();

        uint128 safeTokensAlloc = calculatesSafeTokens(usdcAmount);

        _buy(user, usdcAmount, safeTokensAlloc, 0);

        emit TokensPurchased(user, usdcAmount, safeTokensAlloc, 0, bytes32(0));
    }

    /**
     * @dev Buy safeTokens with a referer
     * @param user The user buying the safeTokens
     * @param refererAddress The referer's address
     * @param usdcAmount The amount of USDC to buy the safeTokens with
     */
    function buyWithReferer(
        address user,
        uint128 usdcAmount,
        address refererAddress
    ) external whenNotPaused {
        if (state != PresaleState.Live) revert PresaleNotLive();

        bytes32 refererId = _hashreferer(refererAddress);

        // check if the referer has invested (a valid referer)
        if (investments[refererAddress] == 0) revert UnknownReferer();
        if (refererAddress == user) revert ReferalToSelf();

        uint128 safeTokensAlloc = calculatesSafeTokens(usdcAmount);

        uint128 refererCommissionAmount = calculateRefererCommission(
            safeTokensAlloc
        );

        _buy(user, usdcAmount, safeTokensAlloc, refererCommissionAmount);

        refererVolume[refererId] += refererCommissionAmount;

        emit TokensPurchased(
            user,
            usdcAmount,
            safeTokensAlloc,
            refererCommissionAmount,
            refererId
        );
    }

    /**
     * @dev Claim safeTokens
     * @notice This function can only be called when the presale has ended
     */
    function claim() external whenNotPaused {
        if (state != PresaleState.Ended) {
            revert PresaleNotEnded();
        }
        uint128 safeTokensToClaim = getTotalsafeTokensOwed(msg.sender);

        investments[msg.sender] = 0;

        refererVolume[_hashreferer(msg.sender)] = 0;

        if (safeTokensToClaim == 0) {
            revert InvalidAllocation();
        }
        safeToken.safeTransfer(msg.sender, safeTokensToClaim);

        emit TokensClaimed(msg.sender, safeTokensToClaim);
    }

    /**
     * @dev Set the token price
     * @param _price The token price to set
     */
    function setTokenPrice(uint128 _price) public onlyOwner {
        tokenPrice = _price;
    }

    /**
     * @dev Set the referer commission
     * @param _commission The referer commission to set
     */
    function setRefererCommission(uint128 _commission) public onlyOwner {
        refererCommission = _commission;
    }

    /**
     * @dev Calculate the safeTokens for a given USDC amount
     * @param usdcAmount The amount of USDC to calculate the safeTokens for
     * @return The safeTokens for the given USDC amount
     */
    function calculatesSafeTokens(
        uint128 usdcAmount
    ) public view returns (uint128) {
        uint128 modifiedPrecision = 1e6;
        return (usdcAmount * tokenPrice) / modifiedPrecision;
    }

    /**
     * @dev Calculate the safeTokens available for sale
     * @return The safeTokens available for sale
     */
    function calculatesSafeTokensAvailable() public view returns (uint128) {
        if (totalSold >= maxSupply) return 0;
        return maxSupply - totalSold;
    }

    /**
     * @dev Pause the presale
     * @notice This function can only be called by the owner
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the presale
     * @notice This function can only be called by the owner
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Start the presale
     * @notice This function can only be called by the owner
     */
    function startPresale() public onlyOwner {
        state = PresaleState.Live;
    }

    /**
     * @dev End the presale
     * @notice This function can only be called by the owner
     */
    function endPresale() public onlyOwner {
        state = PresaleState.Ended;
    }

    /**
     * @dev Calculate the referer commission
     * @param safeTokens The amount of safeTokens to calculate the referer commission for
     * @return The referer commission
     */
    function calculateRefererCommission(
        uint128 safeTokens
    ) public view returns (uint128) {
        if (safeTokens == 0) return 0;
        return (safeTokens * refererCommission) / PRECISION;
    }

    /**
     * @dev Get the total safeTokens owed to a user
     * @param user The user to get the total safeTokens owed for
     */
    function getTotalsafeTokensOwed(
        address user
    ) public view returns (uint128) {
        return investments[user] + refererVolume[_hashreferer(user)];
    }

    /**
     * @dev Set the min and max allocations per wallet
     * @param _min The minimum allocation per wallet
     * @param _max The maximum allocation per wallet
     */
    function setAllocations(uint128 _min, uint128 _max) public onlyOwner {
        if (_min > _max) revert InvalidAllocation();
        minAllocationPerWallet = _min;
        maxAllocationPerWallet = _max;
    }

    /**
     * @dev Deposit safeTokens into the contract
     * @param amount The amount of safeTokens to deposit
     * @param owner The owner of the safeTokens
     */
    function depositSafeTokens(uint128 amount, address owner) public onlyOwner {
        safeToken.safeTransferFrom(owner, address(this), amount);
    }

    ///!@q are withdrawals allowed before the presale ends? / all safeTokens are sold?
    /**
     * @dev Withdraw USDC from the contract
     * @param receiver The receiver of the USDC
     */
    function withdrawUSDC(address receiver) public onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        usdcToken.transfer(receiver, balance);
    }

    /**
     * @dev hash the referer address
     * @param referer The referer address to hash
     */
    function _hashreferer(address referer) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(referer));
    }

    /**
     * @dev retrieve the referer address
     * @param referer The referer id to retrieve
     */
    function _retrievreferer(bytes32 referer) private pure returns (address) {
        return address(uint160(uint256(referer)));
    }

    /**
     * @dev Buy safeTokens
     * @param user The user buying the safeTokens
     * @param usdcAmount The amount of USDC to buy the safeTokens with
     * @param safeTokensAlloc The amount of safeTokens to allocate to the user
     * @param refererCommissionAmount The referer commission amount
     */
    function _buy(
        address user,
        uint128 usdcAmount,
        uint128 safeTokensAlloc,
        uint128 refererCommissionAmount
    ) internal {
        if (safeTokensAlloc == 0) {
            revert InvalidAllocation();
        }

        bytes32 userRefererId = _hashreferer(user); //@audit assumption  - maxAllocationPerWallet includes the referer commission

        uint128 potentialSafeTokensAlloc = investments[user] +
            safeTokensAlloc +
            refererVolume[userRefererId];

        if (
            potentialSafeTokensAlloc < minAllocationPerWallet ||
            potentialSafeTokensAlloc > maxAllocationPerWallet
        ) {
            revert InvalidAllocation();
        }

        // check that the max supply is not exceeded
        if (totalSold + safeTokensAlloc + refererCommissionAmount > maxSupply) {
            revert InvalidAllocation();
        }

        usdcToken.safeTransferFrom(user, address(this), usdcAmount);

        investments[user] += safeTokensAlloc;

        totalSold += safeTokensAlloc + refererCommissionAmount;
    }
}

//!@q is there a cap on referer volume
//!@q does the maxAllocationPerWallet include the referer commission?
//!@ who bears the referers comission the protocol or the user buying
//!@ should withdrawals of usdc be matched with a deposit of  safeTokens for claiming admin side
