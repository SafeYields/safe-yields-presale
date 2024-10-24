// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./interfaces/ISafeYieldLockUp.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeYieldConfigs } from "./interfaces/ISafeYieldConfigs.sol";
import { VestingSchedule } from "./types/SafeTypes.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract SafeYieldLockUp is ISafeYieldLockUp, Ownable2Step, Pausable {
    using Math for uint256;
    using SafeERC20 for IERC20;
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
    IERC20 public sSayToken;
    uint48 public unlockPercentagePerMonth = 2_000; //20%
    mapping(address user => VestingSchedule schedule) public schedules;
    mapping(address user => bool hasVested) public userHasVestedBeforeIDO;
    mapping(address user => bool approved) public approvedVestingAgents;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensVestedFor(address indexed user, uint256 indexed amount);
    event sSayTokensClaimed(address indexed user, uint256 indexed tokensClaimed);
    event VestingAgentApproved(address indexed agent, bool indexed isApproved);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    error SYLU__INVALID_ADDRESS();
    error SYLU__INVALID_AMOUNT();
    error SYLU__ONLY_STAKING();
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
    constructor(address protocolAdmin, address _sSayToken, address safeYieldConfig) Ownable(protocolAdmin) {
        if (protocolAdmin == address(0) || safeYieldConfig == address(0) || _sSayToken == address(0)) {
            revert SYLU__INVALID_ADDRESS();
        }

        configs = ISafeYieldConfigs(safeYieldConfig);
        sSayToken = IERC20(_sSayToken);
    }

    function vestFor(address user, uint256 amount) external override whenNotPaused isValidVestingAgent {
        if (user == address(0)) revert SYLU__INVALID_ADDRESS();
        if (amount == 0) revert SYLU__INVALID_AMOUNT();

        uint48 vestStart = configs.vestStartTime();

        //!@jonathan review
        uint48 startTime = (vestStart == 0) ? vestStart : uint48(block.timestamp);
        bool isBeforeIDO = (vestStart == 0 && !userHasVestedBeforeIDO[user]);
        bool isAfterIDOVestingReset =
            (vestStart != 0 && block.timestamp >= schedules[user].start + schedules[user].duration);

        if (isBeforeIDO || isAfterIDOVestingReset) {
            unlock_sSayTokens();

            schedules[user].start = startTime;
            schedules[user].duration = VESTING_DURATION;
            schedules[user].amountClaimed = 0;
            schedules[user].totalAmount = uint128(amount);

            if (isBeforeIDO) userHasVestedBeforeIDO[user] = true;
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

    function unlock_sSayTokens() public override whenNotPaused returns (uint256 stakedSayTokensAvailable) {
        stakedSayTokensAvailable = unlockedStakedSayToken(msg.sender);

        if (stakedSayTokensAvailable == 0) return 0;

        schedules[msg.sender].amountClaimed += uint128(stakedSayTokensAvailable);

        sSayToken.safeTransfer(msg.sender, stakedSayTokensAvailable);

        emit sSayTokensClaimed(msg.sender, stakedSayTokensAvailable);
    }

    function unlock_sSayTokensFor(address user)
        external
        override
        onlyStaking
        returns (uint256 stakedSayTokensAvailable)
    {
        stakedSayTokensAvailable = unlockedStakedSayToken(user);

        if (stakedSayTokensAvailable == 0) return 0;

        schedules[user].amountClaimed += uint128(stakedSayTokensAvailable);

        sSayToken.safeTransfer(user, stakedSayTokensAvailable);
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

    function unlockedStakedSayToken(address user) public override returns (uint256 unlocked) {
        VestingSchedule memory schedule = schedules[user];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 vested = vestedAmount(user);
        unlocked = vested - schedule.amountClaimed;
    }

    function vestedAmount(address user) public override returns (uint256) {
        VestingSchedule memory schedule = schedules[user];

        //cache
        uint48 vestStartTime = configs.vestStartTime();

        //!Jonathan review
        if (vestStartTime == 0) return 0;

        if (schedule.start == 0 && schedule.totalAmount != 0) {
            //before IDO users
            schedules[user].start = vestStartTime;
        }

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
            uint256 monthsElapsed = durationPassed.mulDiv(BPS, ONE_MONTH);

            uint256 unlockedPercentagePerMonthsElapsed = monthsElapsed.mulDiv(unlockPercentagePerMonth, BPS);

            uint256 totalVested = uint256(schedule.totalAmount).mulDiv(unlockedPercentagePerMonthsElapsed, BPS);

            return totalVested;
        }
    }
}
