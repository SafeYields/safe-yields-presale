// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PreSaleState, Stake, StakingEmissionState } from "./types/SafeTypes.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeYieldRewardDistributor } from "./interfaces/ISafeYieldRewardDistributor.sol";
import { console } from "forge-std/Test.sol";

/**
 * @title SafeYieldStaking contract
 * @dev This contract is used for staking SafeToken.
 * users receive sSafeToken as receipt tokens.
 * Users can earn SafeToken and USDC as rewards.
 */
contract SafeYieldStaking is ISafeYieldStaking, Ownable2Step, ERC20 {
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

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeYieldPreSale public presale;
    ISafeYieldRewardDistributor public distributor;

    uint128 public usdcAccumulatedRewardsPerStake; //@dev accumulated usdc per safe staked.
    uint128 public safeAccumulatedRewardsPerStake; //@dev accumulated safe per safe staked.
    uint128 public totalStaked;
    uint48 public lastUpdateRewardsTimestamp;
    uint256 public lastSafeTokenBalance;
    uint256 public lastUsdcBalance;

    mapping(address user => Stake stake) public userStake;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Staked(address indexed user, uint128 indexed amount);
    event AutoStakedFor(
        address indexed investor, uint128 indexed investorAmount, address indexed referrer, uint128 referrerAmount
    );
    event UnStaked(address indexed user, uint128 indexed amount);
    event RewardsClaimed(address indexed user, uint128 indexed safeRewards, uint128 indexed usdcRewards);
    event RewardDistributorSet(address indexed distributor);
    event PresaleSet(address indexed presale);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SAFE_YIELD_STAKING_LOCKED();
    error SAFE_YIELD_ONLY_PRESALE();
    error SAFE_YIELD_INVALID_STAKE_AMOUNT();
    error SAFE_YIELD_INSUFFICIENT_STAKE();
    error SAFE_YIELD_INVALID_ADDRESS();
    error SAFE_YIELD_STAKED_SAFE_TRANSFER_NOT_ALLOWED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Modifier to lock staking during the presale.
     * If the presale is live, only the presale contract can call the function.
     */
    modifier lockStaking() {
        if (presale.currentPreSaleState() != PreSaleState.Ended) {
            if (msg.sender != address(presale)) {
                revert SAFE_YIELD_STAKING_LOCKED();
            }
        }
        _;
    }

    modifier onlyPresale() {
        if (msg.sender != address(presale)) revert SAFE_YIELD_ONLY_PRESALE();
        _;
    }

    constructor(address _safeToken, address _usdc)
        Ownable(msg.sender)
        ERC20("SafeYield Staked SafeToken", "sSafeToken")
    {
        if (_safeToken == address(0) || _usdc == address(0)) {
            revert SAFE_YIELD_INVALID_ADDRESS();
        }

        safeToken = IERC20(_safeToken);
        usdc = IERC20(_usdc);
    }

    function updateRewards() public override {
        if (totalStaked == 0) {
            lastUpdateRewardsTimestamp = uint48(block.timestamp);
            return;
        }

        if (uint48(block.timestamp) > lastUpdateRewardsTimestamp) {
            /**
             * @dev Distribute rewards to the staking contract.
             * if its during stake emission, rewards are distributed in SafeToken.
             * (35% of the value of safe tokens are minted)
             * Any other state, rewards are distributed in USDC.(60% USDC)
             */
            uint256 shareableRewards = distributor.distributeToContract(address(this));

            uint256 contractUsdcBalance = usdc.balanceOf(address(this));

            uint256 usdcDiff = contractUsdcBalance - lastUsdcBalance;

            if (usdcDiff != 0) {
                usdcAccumulatedRewardsPerStake += SafeCast.toUint128(usdcDiff.mulDiv(PRECISION, totalStaked));

                lastUsdcBalance = contractUsdcBalance;
            }

            if (distributor.isSafeRewardsDistributed()) {
                if (shareableRewards != 0) {
                    safeAccumulatedRewardsPerStake +=
                        SafeCast.toUint128(shareableRewards.mulDiv(PRECISION, totalStaked));
                }
            }

            lastUpdateRewardsTimestamp = uint48(block.timestamp);
        }
    }

    function stakeFor(address user, uint128 amount) public override lockStaking {
        if (amount == 0) revert SAFE_YIELD_INVALID_STAKE_AMOUNT();

        safeToken.safeTransferFrom(msg.sender, address(this), amount);

        updateRewards();

        _stake(user, amount);

        emit Staked(user, amount);
    }

    function autoStakeForBothReferrerAndRecipient(
        address recipient,
        uint128 recipientAmount,
        address referrer,
        uint128 referrerAmount
    ) external override onlyPresale {
        safeToken.safeTransferFrom(msg.sender, address(this), recipientAmount + referrerAmount);

        updateRewards();

        _stake(recipient, recipientAmount);

        _stake(referrer, referrerAmount);

        emit AutoStakedFor(recipient, recipientAmount, referrer, referrerAmount);
    }

    /**
     * @notice called by presale contract to unstake and redeem tokens bought during presale,
     *  only callable by the presale contract.
     * @param user is the user address
     * @param amount is the number of safe tokens to unstake
     */
    function unStakeFor(address user, uint128 amount) external override onlyPresale {
        if (amount == 0) revert SAFE_YIELD_INVALID_STAKE_AMOUNT();
        if (userStake[user].stakeAmount < amount) revert SAFE_YIELD_INSUFFICIENT_STAKE();

        claimRewards(user);

        _unStake(user, amount);

        emit UnStaked(user, amount);
    }

    function unStake(uint128 amount) external override lockStaking {
        if (amount == 0) revert SAFE_YIELD_INVALID_STAKE_AMOUNT();
        if (userStake[msg.sender].stakeAmount < amount) revert SAFE_YIELD_INSUFFICIENT_STAKE();

        claimRewards(msg.sender);

        _unStake(msg.sender, amount);

        emit UnStaked(msg.sender, amount);
    }

    function setPresale(address _presale) external override onlyOwner {
        if (_presale == address(0)) revert SAFE_YIELD_INVALID_ADDRESS();
        presale = ISafeYieldPreSale(_presale);

        emit PresaleSet(_presale);
    }
    /**
     * @notice Set the reward distributor contract.
     * @param _distributor The address of the reward distributor contract.
     */

    function setRewardDistributor(address _distributor) external override onlyOwner {
        if (_distributor == address(0)) revert SAFE_YIELD_INVALID_ADDRESS();
        distributor = ISafeYieldRewardDistributor(_distributor);

        emit RewardDistributorSet(_distributor);
    }

    function getUserStake(address _user) external view override returns (Stake memory) {
        return userStake[_user];
    }

    function claimRewards(address user) public override {
        if (userStake[user].stakeAmount == 0) return;

        updateRewards();

        (
            uint128 pendingUsdcRewards,
            uint128 pendingSafeRewards,
            int128 accumulateUsdcRewards,
            int128 accumulateSafeRewards
        ) = calculatePendingRewards(user);

        /**
         * @dev If the user has pending rewards, the rewards are transferred to the user.
         * If the staking emissions are live, the rewards are transferred in SafeToken.
         * If any other state, the rewards are transferred in USDC.
         */
        if (pendingSafeRewards != 0) {
            userStake[user].safeRewardsDebt = accumulateSafeRewards;

            //safe rewards
            safeToken.safeTransfer(user, pendingSafeRewards);
        }
        if (pendingUsdcRewards != 0) {
            userStake[user].usdcRewardsDebt = accumulateUsdcRewards;

            lastUsdcBalance -= pendingUsdcRewards;
            //usdc rewards
            usdc.safeTransfer(user, pendingUsdcRewards);
        }

        emit RewardsClaimed(user, pendingSafeRewards, pendingUsdcRewards);
    }

    function calculatePendingRewards(address user)
        public
        view
        override
        returns (
            uint128 pendingUsdcRewards,
            uint128 pendingSafeRewards,
            int128 accumulateUsdcRewards,
            int128 accumulateSafeRewards
        )
    {
        Stake memory _userStake = userStake[user];
        uint128 _totalStaked = totalStaked;

        if (_totalStaked == 0 || _userStake.stakeAmount == 0) {
            return (0, 0, 0, 0);
        }

        (uint256 pendingUsdcRewardsToContract, uint256 pendingSafeRewardsToContract) =
            distributor.pendingRewards(address(this));

        uint128 stakingAccSafeRewardsPerStake = safeAccumulatedRewardsPerStake;
        uint128 stakingAccUsdcRewardsPerStake = usdcAccumulatedRewardsPerStake;

        if (pendingUsdcRewardsToContract != 0) {
            stakingAccUsdcRewardsPerStake += uint128(pendingUsdcRewardsToContract.mulDiv(1e18, _totalStaked));
        }

        if (pendingSafeRewardsToContract != 0) {
            stakingAccSafeRewardsPerStake += uint128(pendingSafeRewardsToContract.mulDiv(1e18, _totalStaked));
        }

        accumulateUsdcRewards = SafeCast.toInt128(
            SafeCast.toInt256(
                _userStake.stakeAmount.mulDiv(stakingAccUsdcRewardsPerStake, PRECISION, Math.Rounding.Floor)
            )
        );

        accumulateSafeRewards = SafeCast.toInt128(
            SafeCast.toInt256(
                _userStake.stakeAmount.mulDiv(stakingAccSafeRewardsPerStake, PRECISION, Math.Rounding.Floor)
            )
        );

        /**
         * @dev Calculate the pending rewards for the user.
         * The pending rewards are calculated by subtracting the user's reward debt from the accumulated rewards.
         * Users debt is the amount of rewards the user has already claimed or,
         * the user ineligible to claim because were distributed before they had a stake.
         */
        pendingUsdcRewards =
            SafeCast.toUint128(SafeCast.toUint256(int256(accumulateUsdcRewards - _userStake.usdcRewardsDebt)));

        pendingSafeRewards =
            SafeCast.toUint128(SafeCast.toUint256(int256(accumulateSafeRewards - _userStake.safeRewardsDebt)));
    }

    function _stake(address _user, uint128 amount) internal {
        userStake[_user].stakeAmount += amount;

        userStake[_user].usdcRewardsDebt += SafeCast.toInt128(
            SafeCast.toInt256((amount.mulDiv(usdcAccumulatedRewardsPerStake, PRECISION, Math.Rounding.Floor)))
        );

        userStake[_user].safeRewardsDebt += SafeCast.toInt128(
            SafeCast.toInt256((amount.mulDiv(safeAccumulatedRewardsPerStake, PRECISION, Math.Rounding.Floor)))
        );

        totalStaked += amount;

        _mint(_user, amount);
    }

    function _unStake(address _user, uint128 _amount) internal {
        userStake[_user].stakeAmount -= _amount;

        userStake[_user].usdcRewardsDebt -= SafeCast.toInt128(
            SafeCast.toInt256(_amount.mulDiv(usdcAccumulatedRewardsPerStake, PRECISION, Math.Rounding.Floor))
        );

        userStake[_user].safeRewardsDebt -= SafeCast.toInt128(
            SafeCast.toInt256(_amount.mulDiv(safeAccumulatedRewardsPerStake, PRECISION, Math.Rounding.Floor))
        );

        int256 virtualAccumUsdc = int256(userStake[_user].stakeAmount.mulDiv(usdcAccumulatedRewardsPerStake, 1e18));

        int256 virtualAccumSafe = int256(userStake[_user].stakeAmount.mulDiv(safeAccumulatedRewardsPerStake, 1e18));

        if (userStake[_user].usdcRewardsDebt != virtualAccumUsdc) {
            userStake[_user].usdcRewardsDebt = int128(virtualAccumUsdc);
        }

        if (userStake[_user].safeRewardsDebt != virtualAccumSafe) {
            userStake[_user].safeRewardsDebt = int128(virtualAccumSafe);
        }

        totalStaked -= _amount;

        _burn(_user, _amount);

        safeToken.safeTransfer(_user, _amount);
    }

    ///@dev disable sSafeToken transfer
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            revert SAFE_YIELD_STAKED_SAFE_TRANSFER_NOT_ALLOWED();
        }

        super._update(from, to, value);
    }
}
