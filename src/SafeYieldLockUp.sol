// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";
import { ISafeYieldLockUp } from "./interfaces/ISafeYieldLockUp.sol";
import { VestingSchedule } from "./types/SafeTypes.sol";

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

    uint48 public constant VESTING_DURATION = 150 * 24 * 60 * 60 seconds; // 5 months //todo: verify
    uint48 public constant ONE_MONTH = 24 * 60 * 60 seconds;
    uint48 public constant BPS = 10_000; //100%

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public sayToken;
    ISafeYieldStaking public staking;
    address public safeYieldPresale;
    address public safeYieldAirdrop;
    uint48 public unlockPercentagePerMonth = 2_000; //20%
    mapping(address user => VestingSchedule schedule) public schedules;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensVestedFor(address indexed user, uint256 indexed amount);
    event SayTokensClaimedAndUnStaked(address indexed user, uint256 indexed tokensClaimed);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    error SYLU__INVALID_ADDRESS();
    error SYLU__INVALID_AMOUNT();
    error SYLU__NO_SAY_TO_UNLOCK();
    error SYLU__NOT_PRESALE_OR_AIRDROP();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier lockIfNotPresaleOrAirdrop(address caller) {
        //! no need for parameter, use msg.sender
        if (caller != safeYieldPresale || caller != safeYieldAirdrop) revert SYLU__NOT_PRESALE_OR_AIRDROP();
        _;
    }

    constructor(address protocolAdmin, address _presale, address _airdrop, address _sayToken, address _staking)
        Ownable(protocolAdmin)
    {
        if (
            protocolAdmin == address(0) || _sayToken == address(0) || _presale == address(0) || _airdrop == address(0)
                || _staking == address(0)
        ) {
            revert SYLU__INVALID_ADDRESS();
        }

        sayToken = IERC20(_sayToken);
        staking = ISafeYieldStaking(_staking);

        safeYieldPresale = _presale;
        safeYieldAirdrop = _airdrop;
    }

    function vestFor(address user, uint256 amount) external override {
        if (user == address(0)) revert SYLU__INVALID_ADDRESS();
        if (amount == 0) revert SYLU__INVALID_AMOUNT();

        if (schedules[user].start == 0) {
            schedules[user].start = uint48(block.timestamp);
            schedules[user].duration = VESTING_DURATION;
        }

        schedules[user].totalAmount += uint128(amount);

        emit TokensVestedFor(user, amount);
    }

    function unlockSayTokensFor(address user)
        external
        override
        whenNotPaused
        lockIfNotPresaleOrAirdrop(msg.sender)
        returns (uint256 sayTokensAvailable)
    {
        sayTokensAvailable = unlockedSayAmount(user);

        if (sayTokensAvailable == 0) revert SYLU__NO_SAY_TO_UNLOCK();

        schedules[user].amountClaimed += uint128(sayTokensAvailable);
    }

    // function unlockSayTokens() external whenNotPaused {
    //     uint256 sayTokensAvailable = unlockedSayAmount(msg.sender);

    //     if (sayTokensAvailable == 0) revert SYLU__NO_SAY_TO_UNLOCK();

    //     schedules[msg.sender].amountClaimed += uint128(sayTokensAvailable);

    //     //unstake
    //     staking.unStakeFor(msg.sender, uint128(sayTokensAvailable));

    //     emit SayTokensClaimedAndUnStaked(msg.sender, sayTokensAvailable);
    // }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function getSchedules(address user) external view returns (VestingSchedule memory schedule) {
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
            //! double check the math, careful with the division.
            uint256 monthsElapsed = durationPassed / ONE_MONTH;

            uint256 unlockedPercentagePerMonthsElapsed = monthsElapsed.mulDiv(unlockPercentagePerMonth, BPS);

            uint256 totalVested = uint256(schedule.totalAmount).mulDiv(unlockedPercentagePerMonthsElapsed, BPS);

            return totalVested;
        }
    }
}
