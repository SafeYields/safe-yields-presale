// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./interfaces/ISafeYieldLockUp.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeYieldConfigs } from "./interfaces/ISafeYieldConfigs.sol";
import { VestingSchedule, PreSaleState } from "./types/SafeTypes.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
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
    ISafeYieldConfigs configs;
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
    error SYLU__ONLY_STAKING();
    error SYLU__CANNOT_CLAIM();
    error SYLU__AGENT_NOT_APPROVED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyStaking() {
        if (msg.sender != address(configs.safeYieldStaking())) revert SYLU__ONLY_STAKING();
        _;
    }

    modifier isValidVestingAgent() {
        if (!approvedVestingAgents[msg.sender]) revert SYLU__AGENT_NOT_APPROVED();
        _;
    }

    /**
     * TODO
     * during presale, no vesting start date is known.
     * For each user buying then, their vesting start date is 0
     * Once IDO has started, admin should set the start date.
     * All users who bought during presale will have their tokens start vesting at this date.
     *
     * After IDO is live, use block timestamp as start date for new users.
     */
    constructor(address protocolAdmin, address safeYieldConfig) Ownable(protocolAdmin) {
        if (protocolAdmin == address(0) || safeYieldConfig == address(0)) revert SYLU__INVALID_ADDRESS();

        configs = ISafeYieldConfigs(safeYieldConfig);
    }

    function vestFor(address user, uint256 amount) external override whenNotPaused isValidVestingAgent {
        if (user == address(0)) revert SYLU__INVALID_ADDRESS();
        if (amount == 0) revert SYLU__INVALID_AMOUNT();

        if (block.timestamp >= schedules[user].start + schedules[user].duration) {
            schedules[user].start = configs.vestStartTime();
            schedules[user].duration = VESTING_DURATION;
            schedules[user].amountClaimed = 0;
            schedules[user].totalAmount = uint128(amount);
        } else {
            schedules[user].totalAmount += uint128(amount);
        }

        emit TokensVestedFor(user, amount);
    }

    function approveVestingAgent(address agent, bool isApproved) external override onlyOwner {
        if (agent == address(0)) revert SYLU__INVALID_ADDRESS();

        approvedVestingAgents[agent] = isApproved;

        emit VestingAgentApproved(agent, isApproved);
    }

    function unlockStakedSayTokensFor(address user) external onlyStaking returns (uint256 stakedSayTokensAvailable) {
        stakedSayTokensAvailable = unlockedStakedSayToken(user);

        if (stakedSayTokensAvailable == 0) revert SYLU__NO_SAY_TO_UNLOCK();

        schedules[user].amountClaimed += uint128(stakedSayTokensAvailable);
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

    function unlockedStakedSayToken(address user) public view override returns (uint256 unlocked) {
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
