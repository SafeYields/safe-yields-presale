// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IsSafeToken } from "./interfaces/IsSafeToken.sol";
import { PreSaleState, Stake, StakingEmissionState } from "./types/SafeTypes.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeYieldRewardDistributor } from "./interfaces/ISafeYieldRewardDistributor.sol";
//import { console } from "forge-std/Test.sol";

/**
 * @title SafeYieldStaking contract
 * @author @raiyanmook27
 * @dev This contract is used for staking SafeToken.
 * users receive sSafeToken as receipt tokens.
 * Users can stake SafeToken and USDC to earn rewards.
 */
contract SafeYieldStaking is ISafeYieldStaking, Ownable2Step {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES & CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint128 public constant PRECISION = 1e18;
    IERC20 public immutable safeToken;
    IERC20 public immutable usdc;
    IsSafeToken public immutable sSafeToken;

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeYieldPreSale public presale;
    ISafeYieldRewardDistributor public distributor;
    uint128 public totalStaked;
    uint128 public accumulatedRewardsPerShare; //@dev accumulated usdc/safe per safe staked.
    uint48 public lastUpdateRewardsTimestamp;
    uint256 public lastSafeTokenBalance;
    uint256 public lastUsdcBalance;
    mapping(address user => Stake stake) public userStake;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Staked(address indexed user, uint128 amount);
    event StakedFor(
        address indexed investor, uint128 indexed investorAmount, address indexed referrer, uint128 referrerAmount
    );
    event UnStaked(address indexed user, uint128 amount);
    event RewardsClaimed(address indexed user, uint128 amount);
    event PresaleSet(address presale);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SAFE_YIELD_STAKING_LOCKED();
    error SAFE_YIELD_ONLY_PRESALE();
    error SAFE_YIELD_INVALID_STAKE_AMOUNT();
    error SAFE_YIELD_INSUFFICIENT_STAKE();
    error SAFE_YIELD_INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Modifier to lock staking during the presale.
     * If the presale is live, only the presale contract can call the function.
     */
    modifier lockStaking() {
        //!check if presale has not ended instead
        if (presale.preSaleState() == PreSaleState.Live) {
            if (msg.sender != address(presale)) {
                revert SAFE_YIELD_STAKING_LOCKED();
            }
        }
        _;
    }

    constructor(address _safeToken, address _sSafeToken, address _usdc, address _admin) Ownable(_admin) {
        safeToken = IERC20(_safeToken);
        sSafeToken = IsSafeToken(_sSafeToken);
        usdc = IERC20(_usdc);
    }

    function updateRewards() public override {
        if (totalStaked == 0) {
            lastUpdateRewardsTimestamp = uint48(block.timestamp);
            return;
        }

        if (uint48(block.timestamp) > lastUpdateRewardsTimestamp) {
            uint256 shareableRewards = distributor.distributeToContract(address(this));

            if (shareableRewards != 0) {
                uint128 rewardsPerTokenStaked = SafeCast.toUint128(shareableRewards.mulDiv(PRECISION, totalStaked));

                accumulatedRewardsPerShare += rewardsPerTokenStaked;
            }

            lastUpdateRewardsTimestamp = uint48(block.timestamp);
        }
    }

    function stakeFor(address user, uint128 amount) public override lockStaking {
        if (amount < 1e18) revert SAFE_YIELD_INVALID_STAKE_AMOUNT();

        updateRewards();

        safeToken.safeTransferFrom(msg.sender, address(this), amount);

        _stake(user, amount);

        emit Staked(user, amount);
    }

    function autoStakeForBothReferrerAndRecipient(
        address recipient,
        uint128 recipientAmount,
        address referrer,
        uint128 referrerAmount
    ) external override lockStaking {
        safeToken.safeTransferFrom(msg.sender, address(this), recipientAmount + referrerAmount);

        _stake(recipient, recipientAmount);

        _stake(referrer, referrerAmount);

        emit StakedFor(recipient, recipientAmount, referrer, referrerAmount);
    }

    function unStake(address user, uint128 amount) external override lockStaking {
        if (amount < 1e18) revert SAFE_YIELD_INVALID_STAKE_AMOUNT();
        if (userStake[user].stakeAmount < amount) revert SAFE_YIELD_INSUFFICIENT_STAKE();

        claimRewards();

        userStake[user].stakeAmount -= amount;
        userStake[user].rewardDebt -=
            SafeCast.toInt128(SafeCast.toInt256(amount.mulDiv(accumulatedRewardsPerShare, PRECISION)));

        totalStaked -= amount;

        sSafeToken.burn(user, amount);

        safeToken.safeTransfer(user, amount);

        emit UnStaked(user, amount);
    }

    function getUserStake(address _user) external view override returns (Stake memory) {
        return userStake[_user];
    }

    function setPresale(address _presale) external override onlyOwner {
        if (_presale == address(0)) revert SAFE_YIELD_INVALID_ADDRESS();
        presale = ISafeYieldPreSale(_presale);

        emit PresaleSet(_presale);
    }
    /**
     * @dev Set the reward distributor contract.
     * @param _distributor The address of the reward distributor contract.
     */

    function setRewardDistributor(address _distributor) external override onlyOwner {
        if (_distributor == address(0)) revert SAFE_YIELD_INVALID_ADDRESS();
        distributor = ISafeYieldRewardDistributor(_distributor);
    }

    function claimRewards() public override lockStaking {
        if (userStake[msg.sender].stakeAmount == 0) return;

        updateRewards();

        uint128 pendingRewards = calculatePendingRewards(_msgSender());

        /**
         * @dev If the user has pending rewards, the rewards are transferred to the user.
         * If the staking emissions are live, the rewards are transferred in SafeToken.
         * If any other state, the rewards are transferred in USDC.
         */
        if (pendingRewards != 0) {
            userStake[_msgSender()].rewardDebt = SafeCast.toInt128(SafeCast.toInt256(pendingRewards));

            if (distributor.currentStakingState() == StakingEmissionState.Live) {
                //safe rewards
                safeToken.safeTransfer(_msgSender(), pendingRewards);
            } else {
                //usdc rewards
                usdc.safeTransfer(_msgSender(), pendingRewards);
            }

            emit RewardsClaimed(_msgSender(), pendingRewards);

            return;
        }
    }

    function calculatePendingRewards(address user) public override returns (uint128 pendingRewards) {
        if (totalStaked == 0 || userStake[user].stakeAmount == 0) {
            return 0;
        }

        updateRewards();

        int128 accumulatedRewards = SafeCast.toInt128(
            SafeCast.toInt256(userStake[user].stakeAmount.mulDiv(accumulatedRewardsPerShare, PRECISION))
        );

        /**
         * @dev Calculate the pending rewards for the user.
         * The pending rewards are calculated by subtracting the user's reward debt from the accumulated rewards.
         * users debt is the amount of rewards the user has already claimed.
         */
        pendingRewards = SafeCast.toUint128(SafeCast.toUint256(accumulatedRewards - userStake[user].rewardDebt));
    }

    function _stake(address _user, uint128 amount) internal {
        userStake[_user].stakeAmount += amount;
        userStake[_user].rewardDebt +=
            SafeCast.toInt128(SafeCast.toInt256((amount.mulDiv(accumulatedRewardsPerShare, PRECISION))));

        totalStaked += amount;

        sSafeToken.mint(_user, amount);
    }
}
