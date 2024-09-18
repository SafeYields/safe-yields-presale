// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ISafeYieldStaking } from "../src/interfaces/ISafeYieldStaking.sol";
import { ISafeYieldTokensDistributor } from "../src/interfaces/ISafeYieldTokensDistributor.sol";
import { Stake } from "./types/SafeTypes.sol";

/**
 * @title SafeYieldTokensDistributor
 * @notice Distributes multiple reward tokens to stakers based on their stakes.
 * @author 0xm00k (GitHub: 0xm00k)
 */
contract SafeYieldTokensDistributor is ISafeYieldTokensDistributor, Ownable2Step, Pausable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address[] public approvedTokens;
    uint48 public lastUpdateRewardsTimestamp;
    ISafeYieldStaking public staking;

    mapping(address token => uint256 accumRewards) public accumulatedRewards;
    mapping(address user => int256 rewardDebt) public userRewardDebt;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event StakingUpdated(address indexed oldStaking, address indexed newStaking);
    event TokensApproved(address[] indexed tokens);
    event RewardsClaimed(address user, address rewardToken, uint256 pendingRewards);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SY_TD__INVALID_ADDRESS();
    error SY_TD__NO_STAKE();
    error SY_TD__INVALID_TOKENS_LENGTH();

    constructor(address _staking, address protocolAdmin) Ownable(protocolAdmin) {
        if (address(_staking) == address(0) || protocolAdmin == address(0)) revert SY_TD__INVALID_ADDRESS();

        staking = ISafeYieldStaking(_staking);
    }

    function approveRewardTokens(address[] calldata tokens) external override onlyOwner {
        uint8 numOfTokens = uint8(tokens.length);
        if (numOfTokens == 0) revert SY_TD__INVALID_TOKENS_LENGTH();
        //!note check if token already exist
        //!note check if token is address 0

        for (uint8 i; i < numOfTokens; i++) {
            approvedTokens.push(tokens[i]);
        }

        emit TokensApproved(tokens);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function updateStaking(address newStaking) external override onlyOwner {
        if (newStaking == address(0)) revert SY_TD__INVALID_ADDRESS();

        address oldStaking = address(staking);

        staking = ISafeYieldStaking(newStaking);

        emit StakingUpdated(oldStaking, newStaking);
    }

    function updateRewards() public {
        uint128 totalStaked = staking.totalStaked();

        if (totalStaked == 0) {
            lastUpdateRewardsTimestamp == uint48(block.timestamp);

            return;
        }

        uint8 numOfTokens = uint8(approvedTokens.length);
        uint48 currentTimeStamp = uint48(block.timestamp);

        if (currentTimeStamp > lastUpdateRewardsTimestamp) {
            for (uint8 i; i < numOfTokens; i++) {
                address rewardToken = approvedTokens[i];

                uint256 rewardShareable = IERC20(rewardToken).balanceOf(address(this));

                if (rewardShareable != 0) {
                    uint256 rewardPerStake = rewardShareable.mulDiv(1e18, totalStaked);

                    accumulatedRewards[rewardToken] += rewardPerStake;
                }
            }

            lastUpdateRewardsTimestamp = currentTimeStamp;
        }
    }

    function claimRewards() public override whenNotPaused {
        Stake memory userStake = staking.getUserStake(msg.sender);

        if (userStake.stakeAmount == 0) revert SY_TD__NO_STAKE();

        updateRewards();

        uint8 numOfTokens = uint8(approvedTokens.length);

        uint256[] memory pendingTokenRewards = pendingRewards(msg.sender);

        for (uint8 i; i < numOfTokens; i++) {
            address rewardToken = approvedTokens[i];

            userRewardDebt[rewardToken] =
                int256(uint256(userStake.stakeAmount).mulDiv(accumulatedRewards[rewardToken], 1e18));

            if (pendingTokenRewards[i] != 0) {
                IERC20(rewardToken).safeTransfer(msg.sender, pendingTokenRewards[i]);

                emit RewardsClaimed(msg.sender, rewardToken, pendingTokenRewards[i]);
            }
        }
    }

    function pendingRewards(address user) public view override returns (uint256[] memory pendingTokenRewards) {
        uint128 totalStaked = staking.totalStaked();

        uint8 numOfTokens = uint8(approvedTokens.length);
        //!note check if there are tokens

        Stake memory userStake = staking.getUserStake(user);
        if (totalStaked == 0 || userStake.stakeAmount == 0) {
            return pendingTokenRewards;
        }

        for (uint48 i; i < numOfTokens; i++) {
            address rewardToken = approvedTokens[i];

            int256 userAccumulatedRewards =
                int256(uint256(userStake.stakeAmount).mulDiv(accumulatedRewards[rewardToken], 1e18));

            pendingTokenRewards[i] = uint256(userAccumulatedRewards - userRewardDebt[user]);
        }
    }

    function handleActionBefore(address _user, bytes4 _selector) external { }

    function handleActionAfter(address _user, bytes4 _selector) external { }
}
