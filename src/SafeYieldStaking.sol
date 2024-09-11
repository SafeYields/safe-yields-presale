// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PreSaleState, Stake, StakingEmissionState } from "./types/SafeTypes.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./interfaces/ISafeYieldLockUp.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeYieldRewardDistributor } from "./interfaces/ISafeYieldRewardDistributor.sol";

/**
 * @title SafeYieldStaking contract
 * @dev This contract is used for staking SafeToken.
 * users receive sSafeToken as receipt tokens.
 * Users can earn SafeToken and USDC as rewards.
 */
contract SafeYieldStaking is ISafeYieldStaking, Ownable2Step, ERC20, Pausable {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;

    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES & CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint128 public constant PRECISION = 1e18;
    IERC20 public immutable usdc;

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeYieldPreSale public safeYieldPresale;
    ISafeYieldRewardDistributor public distributor;
    ISafeYieldLockUp public safeYieldLockUp;
    IERC20 public safeToken;
    address public safeYieldLP;

    uint128 public usdcAccumulatedRewardsPerStake; //@dev accumulated usdc per safe staked.
    uint128 public safeAccumulatedRewardsPerStake; //@dev accumulated safe per safe staked.
    uint128 public override totalStaked;
    uint48 public lastUpdateRewardsTimestamp;
    uint256 public lastSafeTokenBalance;
    uint256 public lastUsdcBalance;

    mapping(address user => Stake stake) public userStake;
    mapping(address user => bool approved) public approvedStakingAgent;

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
    event SafeYieldLpSet(address indexed lp);
    event LockUpSet(address indexed lockUp);
    event SafeTokenUpdated(address indexed newSafeToken);
    event StakingAgentApproved(address indexed agent, bool indexed isApproved);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SYST__STAKING_LOCKED();
    error SYST__INVALID_STAKE_AMOUNT();
    error SYST__INSUFFICIENT_STAKE();
    error SYST__INVALID_ADDRESS();
    error SYST__NOT_APPROVED();
    error SYST__ID0_NOT_ENDED();
    error SYST__ONLY_LOCKUP();
    error SYST__ONLY_PRESALE();
    error SYST__STAKED_SAFE_TRANSFER_NOT_ALLOWED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier lockStaking() {
        if ((safeYieldPresale.currentPreSaleState() != PreSaleState.Ended) || safeYieldLP == address(0)) {
            revert SYST__STAKING_LOCKED();
        }
        _;
    }

    modifier onlySafeYieldLockUp() {
        if (msg.sender != address(safeYieldLockUp)) revert SYST__ONLY_LOCKUP();
        _;
    }

    modifier onlySafeYieldPresale() {
        if (msg.sender != address(safeYieldPresale)) revert SYST__ONLY_PRESALE();
        _;
    }

    modifier isValidStakingAgent() {
        if (!approvedStakingAgent[msg.sender]) revert SYST__NOT_APPROVED();
        _;
    }

    constructor(address _safeToken, address _usdc) Ownable(msg.sender) ERC20("Staked SayToken", "sSayToken") {
        if (_safeToken == address(0) || _usdc == address(0)) {
            revert SYST__INVALID_ADDRESS();
        }

        safeToken = IERC20(_safeToken);
        usdc = IERC20(_usdc);
    }

    function stakeFor(address user, uint128 amount) external override whenNotPaused isValidStakingAgent {
        if (user == address(0)) revert SYST__INVALID_ADDRESS();
        if (amount == 0) revert SYST__INVALID_STAKE_AMOUNT();

        safeToken.safeTransferFrom(msg.sender, address(this), amount);

        updateRewards();

        _stake(user, amount);

        _mint(address(safeYieldLockUp), amount);

        safeYieldLockUp.vestFor(user, amount);

        emit Staked(user, amount);
    }

    function autoStakeForBothReferrerAndRecipient(
        address recipient,
        uint128 recipientAmount,
        address referrer,
        uint128 referrerAmount
    ) external override onlySafeYieldPresale {
        safeToken.safeTransferFrom(msg.sender, address(this), recipientAmount + referrerAmount);

        updateRewards();

        _stake(recipient, recipientAmount);

        _stake(referrer, referrerAmount);

        emit AutoStakedFor(recipient, recipientAmount, referrer, referrerAmount);
    }

    function unStakeFor(address user, uint128 amount) external override onlySafeYieldLockUp {
        if (user == address(0)) revert SYST__INVALID_ADDRESS();
        if (amount == 0) revert SYST__INVALID_STAKE_AMOUNT();

        if (userStake[user].stakeAmount < amount) revert SYST__INSUFFICIENT_STAKE();

        claimRewards(user);

        _unStake(user, amount);

        _burn(address(safeYieldLockUp), amount);

        safeToken.safeTransfer(user, amount);

        emit UnStaked(user, amount);
    }

    function stake(uint128 amount) external whenNotPaused lockStaking {
        if (safeYieldLP == address(0)) revert SYST__ID0_NOT_ENDED();
        if (amount == 0) revert SYST__INVALID_STAKE_AMOUNT();

        safeToken.safeTransferFrom(msg.sender, address(this), amount);

        _stake(msg.sender, amount);

        _mint(msg.sender, amount);

        emit Staked(msg.sender, amount);
    }

    function unStake(uint128 amount) external override whenNotPaused lockStaking {
        if (amount == 0) revert SYST__INVALID_STAKE_AMOUNT();
        if (userStake[msg.sender].stakeAmount < amount) revert SYST__INSUFFICIENT_STAKE();

        claimRewards(msg.sender);

        _unStake(msg.sender, amount);

        _burn(msg.sender, amount);

        safeToken.safeTransfer(msg.sender, amount);

        emit UnStaked(msg.sender, amount);
    }

    function approveStakingAgent(address agent) external override onlyOwner {
        if (agent == address(0)) revert SYST__INVALID_ADDRESS();

        approvedStakingAgent[agent] ? approvedStakingAgent[agent] = false : approvedStakingAgent[agent] = true;

        emit StakingAgentApproved(agent, approvedStakingAgent[agent]);
    }

    function setLpAddress(address lp) external override onlyOwner {
        if (lp == address(0)) revert SYST__INVALID_ADDRESS();

        safeYieldLP = lp;

        emit SafeYieldLpSet(lp);
    }

    function updateSafeToken(address newSafeToken) external override onlyOwner {
        if (newSafeToken == address(0)) revert SYST__INVALID_ADDRESS();

        safeToken = IERC20(newSafeToken);

        emit SafeTokenUpdated(newSafeToken);
    }

    //todo: token distributor callbacks for stake and unstake ops.

    function setPresale(address _presale) external override onlyOwner {
        if (_presale == address(0)) revert SYST__INVALID_ADDRESS();

        safeYieldPresale = ISafeYieldPreSale(_presale);

        emit PresaleSet(_presale);
    }

    function setLockUp(address _lockUp) external override onlyOwner {
        if (_lockUp == address(0)) revert SYST__INVALID_ADDRESS();

        safeYieldLockUp = ISafeYieldLockUp(_lockUp);

        emit LockUpSet(_lockUp);
    }

    /**
     * @notice Set the reward distributor contract.
     * @param _distributor The address of the reward distributor contract.
     */
    function setRewardDistributor(address _distributor) external override onlyOwner {
        if (_distributor == address(0)) revert SYST__INVALID_ADDRESS();

        distributor = ISafeYieldRewardDistributor(_distributor);

        emit RewardDistributorSet(_distributor);
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

    function getUserStake(address _user) external view override returns (Stake memory) {
        return userStake[_user];
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

    function claimRewards(address user) public override whenNotPaused {
        if (userStake[user].stakeAmount == 0) return;

        updateRewards();

        (
            uint128 pendingUsdcRewards,
            uint128 pendingSafeRewards,
            int128 accumulateUsdcRewards,
            int128 accumulateSafeRewards
        ) = calculatePendingRewards(user);

        /**
         * @dev Transfers pending rewards to the user if available.
         * Users can claim their pending USDC and SAFE rewards at any time.
         * Example: If a user has accrued 100 SAFE rewards during the staking emissions
         *       but has not claimed them, they can return after the staking period ends
         *       and still claim the 100 SAFE rewards along with 100 USDC rewards.
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

    function updateRewards() public override whenNotPaused {
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

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            revert SYST__STAKED_SAFE_TRANSFER_NOT_ALLOWED();
        }

        super._update(from, to, value);
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
    }
}
