// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISSafeToken} from "./interfaces/IsSafeToken.sol";
import {PreSaleState, Stake} from "./types/SafeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ISafeYieldStaking} from "./interfaces/ISafeYieldStaking.sol";
import {ISafeYieldPreSale} from "./interfaces/ISafeYieldPreSale.sol";

contract SafeYieldStaking is ISafeYieldStaking, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable safeToken;
    ISSafeToken public immutable sSafeToken;
    IERC20 public immutable usdc;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeYieldPreSale public presale;
    uint64 usdcRewardRate; // time
    uint64 safeTokenRewardRate; // time
    uint128 usdcRewardPerShare;
    uint128 safeTokenRewardPerShare;
    uint128 lastRewardUpdateTimestamp;
    uint128 totalStaked;
    mapping(address user => Stake stake) public userStakes;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Staked(address indexed user, uint128 amount);
    event StakedFor(
        address indexed investor,
        uint128 indexed investorAmount,
        address indexed referrer,
        uint128 referrerAmount
    );
    event UnStaked(address indexed user, uint128 amount);
    event UsdcRewardPerShareUpdated(uint128 newRewardPerShare);
    event SafeTokenRewardPerShareUpdated(uint128 newRewardPerShare);
    event RewardClaimed(address indexed user, uint128 amount, bool isUsdc);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SAFE_YIELD_STAKING_LOCKED();
    error SAFE_YIELD_STAKING();

    constructor(
        address _safeToken,
        address _sSafeToken,
        address _usdc,
        address _admin
    ) Ownable(_admin) {
        safeToken = IERC20(_safeToken);
        sSafeToken = ISSafeToken(_sSafeToken);
        usdc = IERC20(_usdc);
    }

    modifier updateReward(address user) {
        (
            uint128 usdcRewardsPerToken,
            uint128 safeRewardPerToken
        ) = rewardsPerToken();
        usdcRewardPerShare = usdcRewardsPerToken;
        safeTokenRewardPerShare = safeRewardPerToken;
        lastRewardUpdateTimestamp = uint128(block.timestamp);

        (
            uint128 pendingUsdcReward,
            uint128 pendingSafeTokenReward
        ) = rewardsEarned();

        userStakes[user].usdcRewards += pendingUsdcReward;
        userStakes[user].safeRewards += pendingSafeTokenReward;

        userStakes[user].usdcPerTokenRewardClaimed = usdcRewardsPerToken;
        userStakes[user].safePerTokenRewardClaimed = safeRewardPerToken;
        _;
    }

    modifier lockStaking() {
        if (
            presale.preSaleState() == PreSaleState.Live &&
            msg.sender != address(presale)
        ) revert SAFE_YIELD_STAKING_LOCKED();
        _;
    }

    function rewardsEarned()
        public
        view
        override
        returns (uint128 pendingUsdcReward, uint128 pendingSafeTokenReward)
    {
        // Calculate the user's pending USDC reward
        (
            uint128 usdcRewardPerToken,
            uint128 safeTokenRewardPerToken
        ) = rewardsPerToken();

        if (userStakes[msg.sender].stakedSafeTokenAmount == 0) {
            return (0, 0);
        }

        pendingUsdcReward =
            ((userStakes[msg.sender].stakedSafeTokenAmount *
                usdcRewardPerToken) / 1e18) +
            userStakes[msg.sender].usdcRewards;

        // Calculate the user's pending SafeToken reward
        pendingSafeTokenReward =
            ((userStakes[msg.sender].stakedSafeTokenAmount *
                safeTokenRewardPerToken) / 1e18) -
            userStakes[msg.sender].safeRewards;

        // Return the user's pending rewards

        return (pendingUsdcReward, pendingSafeTokenReward);
    }

    function rewardsPerToken()
        public
        view
        override
        returns (uint128 usdcRewardsPerToken, uint128 safeTokenRewardsPerToken)
    {
        if (totalStaked == 0) {
            return (0, 0);
        }
        usdcRewardPerShare +
            ((usdcRewardRate *
                (uint128(block.timestamp) - lastRewardUpdateTimestamp) *
                1e18) / totalStaked); // 18 decimals
        safeTokenRewardsPerToken =
            safeTokenRewardPerShare +
            ((safeTokenRewardRate *
                (uint128(block.timestamp) - lastRewardUpdateTimestamp) *
                1e18) / totalStaked); // 18 decimals

        return (usdcRewardsPerToken, safeTokenRewardsPerToken);
    }

    // The stake function
    function stake(
        uint128 amount,
        address user
    ) public override lockStaking updateReward(user) {
        safeToken.transferFrom(msg.sender, address(this), amount);

        sSafeToken.mint(user, amount); // receipt token representing the stake

        userStakes[user].stakedSafeTokenAmount += amount;

        totalStaked += amount;

        emit Staked(user, amount);
    }

    // The unstake function
    function unstake(
        address user,
        uint128 amount
    ) public override lockStaking updateReward(user) {
        // Transfer the amount of SafeToken from this contract to the sender

        if (amount > userStakes[user].stakedSafeTokenAmount) {
            revert("Insufficient staked amount");
        }

        sSafeToken.burn(user, amount);

        userStakes[user].stakedSafeTokenAmount -= amount;

        totalStaked -= amount;

        safeToken.transfer(user, amount);

        emit UnStaked(user, amount);
    }

    function stakeFor(
        address investor,
        uint128 investorAmount,
        address referrer,
        uint128 referrerAmount
    ) external override {
        if (msg.sender != address(presale)) revert SAFE_YIELD_STAKING();

        sSafeToken.mint(investor, investorAmount);

        sSafeToken.mint(referrer, referrerAmount);

        userStakes[investor].stakedSafeTokenAmount += investorAmount;

        userStakes[referrer].stakedSafeTokenAmount += referrerAmount;

        totalStaked += (investorAmount + referrerAmount);

        emit StakedFor(investor, investorAmount, referrer, referrerAmount);
    }

    function claimReward()
        external
        override
        lockStaking
        updateReward(msg.sender)
    {
        //fund the contract from rewards pool
        uint128 rewards = userStakes[msg.sender].safeRewards;
        uint128 usdcRewards = userStakes[msg.sender].usdcRewards;

        if (rewards > 0) {
            userStakes[msg.sender].safeRewards = 0;
            safeToken.transfer(msg.sender, rewards);
            emit RewardClaimed(msg.sender, rewards, false);
        }

        if (usdcRewards > 0) {
            userStakes[msg.sender].usdcRewards = 0;
            usdc.transfer(msg.sender, usdcRewards);
            emit RewardClaimed(msg.sender, usdcRewards, true);
        }
    }

    function updateUsdcRewardPerShare(
        uint128 newRewardPerShare
    ) external override onlyOwner {
        //access controlled
        usdcRewardPerShare = newRewardPerShare;
        emit UsdcRewardPerShareUpdated(newRewardPerShare);
    }

    function updateSafeTokenRewardPerShare(
        uint128 newRewardPerShare
    ) external override onlyOwner {
        //access controlled
        safeTokenRewardPerShare = newRewardPerShare;

        emit SafeTokenRewardPerShareUpdated(newRewardPerShare);
    }

    function updateUsdcRewardRate(uint64 newRewardRate) external onlyOwner {
        //access controlled
        usdcRewardRate = newRewardRate;
    }

    function updateSafeTokenRewardRate(
        uint64 newRewardRate
    ) external override onlyOwner {
        //access controlled
        safeTokenRewardRate = newRewardRate;
    }

    function setPresale(address _presale) external override onlyOwner {
        presale = ISafeYieldPreSale(_presale);
    }
}
