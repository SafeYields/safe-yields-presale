// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SafeStakingContract {
    // The SafeToken contract, the staked token
    IERC20 public immutable safeToken;

    struct MyStake {
        uint128 stakedSafeTokenAmount;
        uint128 accumulatedUsdcRewardsPerShare;
        uint128 usdcRewardClaimed;
        uint128 accumulatedSafeTokenRewardsPerShare;
        uint128 safeTokenRewardClaimed;
        uint256 lastRewardUpdateTimestamp;
    }

    uint128 usdcRewardPerShare;
    uint128 safeTokenRewardPerShare;

    mapping(address user => MyStake stake) public userStakes;

    // staked 1000
    // usdcRewardPerShare 0.1
    // safeTokenRewardPerShare 0.2
    // I have 0.1 * 1000 = 100 usdc

    // claim 100 usdc

    // reward per share stays same
    // claim 100 usdc - 100 usdc = 0 usdc

    // reward per share becomes 0.2
    // claim 0.2 * 1000 = 200 safeToken
    // claim 200 usdc - 100 usdc = 100 usdc

    // reward per share becomes 0.3
    // claim 0.3 * 1000 = 300 safeToken

    //stake additional 1000
    // accumulatedUsdcRewardsPerShare = 300
    // total

    // The SafeStakingContract constructor
    constructor(address _safeToken) {
        safeToken = IERC20(_safeToken);
    }

    // The stake function
    function stake(uint128 amount) public {
        safeToken.transferFrom(msg.sender, address(this), amount);

        MyStake memory userStake = userStakes[msg.sender];

        // Update the user's pending reward
        userStakes[msg.sender].accumulatedUsdcRewardsPerShare += ((userStake
            .stakedSafeTokenAmount * usdcRewardPerShare) / 1e18);
        userStakes[msg.sender]
            .accumulatedSafeTokenRewardsPerShare += ((userStake
            .stakedSafeTokenAmount * safeTokenRewardPerShare) / 1e18);

        userStakes[msg.sender].lastRewardUpdateTimestamp = block.timestamp;

        // Update the user's stake
        userStakes[msg.sender].stakedSafeTokenAmount += amount;
    }

    // The unstake function
    function unstake(uint256 amount) public {
        // Transfer the amount of SafeToken from this contract to the sender
        safeToken.transfer(msg.sender, amount);

        //burn sSafeToken

        // Update the user's stake

        // Update the user's pending USDC reward

        // Update the user's pending SafeToken reward

        // Update the user's last reward update timestamp

        //give rewards
    }

    function updateUsdcRewardPerShare(uint128 newRewardPerShare) public {
        //access controlled
        usdcRewardPerShare = newRewardPerShare;
    }

    function updateSafeTokenRewardPerShare(uint128 newRewardPerShare) public {
        //access controlled
        safeTokenRewardPerShare = newRewardPerShare;
    }

    function myRewards(address user) public view returns (uint128, uint128) {
        // Calculate the user's pending USDC reward
        uint128 pendingUsdcReward = ((userStakes[user].stakedSafeTokenAmount *
            usdcRewardPerShare) / 1e18) - userStakes[user].usdcRewardClaimed;

        // Calculate the user's pending SafeToken reward
        uint128 pendingSafeTokenReward = ((userStakes[user]
            .stakedSafeTokenAmount * safeTokenRewardPerShare) / 1e18) -
            userStakes[user].safeTokenRewardClaimed;

        // Return the user's pending rewards

        return (pendingUsdcReward, pendingSafeTokenReward);
    }

    function _updateUSDCReward(address user) private {
        // Calculate the user's pending USDC reward
        uint128 pendingUsdcReward = ((userStakes[user].stakedSafeTokenAmount *
            usdcRewardPerShare) / 1e18) - userStakes[user].usdcRewardClaimed;
        userStakes[user].accumulatedUsdcRewardsPerShare += pendingUsdcReward;
        userStakes[user].lastRewardUpdateTimestamp = block.timestamp;
    }

    function _updateSafeTokenReward(
        address user,
        uint128 rewardClaimed
    ) private {
        // Calculate the user's pending SafeToken reward
        uint128 pendingSafeTokenReward = ((userStakes[user]
            .stakedSafeTokenAmount * safeTokenRewardPerShare) / 1e18) -
            userStakes[user].safeTokenRewardClaimed;
        userStakes[user]
            .accumulatedSafeTokenRewardsPerShare += pendingSafeTokenReward;
        userStakes[user].lastRewardUpdateTimestamp = block.timestamp;
    }
}
