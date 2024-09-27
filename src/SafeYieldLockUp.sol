// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./interfaces/ISafeYieldLockUp.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { VestingSchedule, PreSaleState } from "./types/SafeTypes.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract SafeYieldLockUp is ISafeYieldLockUp, Ownable2Step, Pausable {
    using Math for uint256;
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint48 public constant VESTING_DURATION = 5 * 30 * 24 * 60 * 60 seconds; //5 months
    uint48 public constant ONE_MONTH = 30 * 24 * 60 * 60 seconds; //1 month
    uint48 public constant BPS = 10_000; //100%

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public sayToken;
    ISafeYieldStaking public staking;
    ISafeYieldPreSale public safeYieldPresale;

    uint48 public unlockPercentagePerMonth = 2_000; //20%
    mapping(address user => VestingSchedule schedule) public schedules;
    mapping(address user => bool approved) public approvedVestingAgents;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensVestedFor(address indexed user, uint256 indexed amount);
    event SayTokensClaimed(address indexed user, uint256 indexed tokensClaimed);
    event SayTokenAddressUpdated(address indexed newSayToken);
    event PreSaleAddressUpdated(address indexed newPresale);
    event StakingAddressUpdated(address indexed newStaking);
    event VestingAgentApproved(address indexed agent, bool indexed isApproved);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    error SYLU__INVALID_ADDRESS();
    error SYLU__INVALID_AMOUNT();
    error SYLU__NO_SAY_TO_UNLOCK();
    error SYLU__NOT_PRESALE_OR_AIRDROP();
    error SYLU__ONLY_STAKING();
    error SYLU__CANNOT_CLAIM();
    error SYLU__AGENT_NOT_APPROVED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyStaking() {
        if (msg.sender != address(staking)) revert SYLU__ONLY_STAKING();
        _;
    }

    modifier canClaim() {
        if (safeYieldPresale.currentPreSaleState() != PreSaleState.Ended) revert SYLU__CANNOT_CLAIM();
        _;
    }

    modifier isValidVestingAgent() {
        if (!approvedVestingAgents[msg.sender]) revert SYLU__AGENT_NOT_APPROVED();
        _;
    }

    constructor(address protocolAdmin, address _presale, address _sayToken, address _staking) Ownable(protocolAdmin) {
        if (protocolAdmin == address(0) || _sayToken == address(0) || _presale == address(0) || _staking == address(0))
        {
            revert SYLU__INVALID_ADDRESS();
        }

        sayToken = IERC20(_sayToken);
        staking = ISafeYieldStaking(_staking);
        safeYieldPresale = ISafeYieldPreSale(_presale);
    }

    function vestFor(address user, uint256 amount) external override whenNotPaused isValidVestingAgent {
        if (user == address(0)) revert SYLU__INVALID_ADDRESS();
        if (amount == 0) revert SYLU__INVALID_AMOUNT();

        if (block.timestamp >= schedules[user].start + schedules[user].duration) {
            schedules[user].start = uint48(block.timestamp);
            schedules[user].duration = VESTING_DURATION;
        }

        schedules[user].totalAmount += uint128(amount);

        emit TokensVestedFor(user, amount);
    }

    function approveStakingAgent(address agent, bool isApproved) external override onlyOwner {
        if (agent == address(0)) revert SYLU__INVALID_ADDRESS();

        approvedVestingAgents[agent] = isApproved;

        emit VestingAgentApproved(agent, isApproved);
    }

    function unlockSayTokens() external override whenNotPaused canClaim {
        uint256 sayTokensAvailable = unlockedSayAmount(msg.sender);

        if (sayTokensAvailable == 0) revert SYLU__NO_SAY_TO_UNLOCK();

        schedules[msg.sender].amountClaimed += uint128(sayTokensAvailable);

        staking.unStakeFor(msg.sender, uint128(sayTokensAvailable));

        emit SayTokensClaimed(msg.sender, sayTokensAvailable);
    }

    function updateSayToken(address newSayToken) external override onlyOwner {
        if (newSayToken == address(0)) revert SYLU__INVALID_ADDRESS();

        sayToken = IERC20(newSayToken);

        emit SayTokenAddressUpdated(newSayToken);
    }

    function updateStaking(address newStaking) external override onlyOwner {
        if (newStaking == address(0)) revert SYLU__INVALID_ADDRESS();

        staking = ISafeYieldStaking(newStaking);

        emit StakingAddressUpdated(newStaking);
    }

    function updatePreSale(address newPresale) external override onlyOwner {
        if (newPresale == address(0)) revert SYLU__INVALID_ADDRESS();

        safeYieldPresale = ISafeYieldPreSale(newPresale);

        emit PreSaleAddressUpdated(newPresale);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function getSchedules(address user) external view override returns (VestingSchedule memory schedule) {
        return schedules[user];
    }

    function unlockedSayAmount(address user) public view override returns (uint256 unlocked) {
        VestingSchedule memory schedule = schedules[user];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 vested = vestedAmount(user);
        unlocked = vested - schedule.amountClaimed;
    }

    function vestedAmount(address user) public view override returns (uint256) {
        VestingSchedule memory schedule = schedules[user];

        if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            uint256 durationPassed = block.timestamp - schedule.start;

            /**
             * Alice total Vested = 1000 tokens
             * Unlock per month = 20%
             *
             * After 2.5 months
             * months elapsed = 2.5 months / one month
             * unlockedPercentagePerMonthsElapsed = 2.5 * 20% = 50%
             * total vested = (1000 * 50 ) / 100 = 500
             */
            //todo! double check the math, careful with the division.
            uint256 monthsElapsed = durationPassed.mulDiv(BPS, ONE_MONTH);

            uint256 unlockedPercentagePerMonthsElapsed = monthsElapsed.mulDiv(unlockPercentagePerMonth, BPS);

            uint256 totalVested = uint256(schedule.totalAmount).mulDiv(unlockedPercentagePerMonthsElapsed, BPS);

            return totalVested;
        }
    }
}
