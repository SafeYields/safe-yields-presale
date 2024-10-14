//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ISafeYieldConfigs } from "./interfaces/ISafeYieldConfigs.sol";
import { RewardToken, Rewards } from "./types/SafeTypes.sol";
import { ISafeYieldStaking } from "../src/interfaces/ISafeYieldStaking.sol";
import { ISafeYieldStakingCallback } from "./interfaces/ISafeYieldStakingCallback.sol";
import { ISafeYieldTokensDistributor } from "./interfaces/ISafeYieldTokensDistributor.sol";

contract SafeYieldTokenDistributor is ISafeYieldTokensDistributor, Ownable2Step, Pausable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES & CONSTANT
    //////////////////////////////////////////////////////////////*/
    uint256 public constant DIVISION_FACTOR = 1e18;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address[] internal allRewardTokens;
    ISafeYieldConfigs configs;
    mapping(address user => mapping(address rewardToken => int256 rewardDebt)) public userTokenRewardDebt;
    mapping(address user => uint256 stakeBalance) public lastStakeBalance;
    mapping(address rewardToken => RewardToken) public rewardTokens;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RewardDeposited(address indexed owner, address indexed rewardAsset, uint256 indexed amount);
    event RewardsClaimed(address indexed user, address indexed rewardAsset, uint256 indexed _pendingReward);

    /*//////////////////////////////////////////////////////////////
                                 ERROR
    //////////////////////////////////////////////////////////////*/
    error SYTD__LENGTH_MISMATCH();
    error SYTD__INVALID_ADDRESS();
    error SYTD__UNAUTHORIZED();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyStaking() {
        if (msg.sender != address(configs.safeYieldStaking())) revert SYTD__UNAUTHORIZED();
        _;
    }

    constructor(address protocolAdmin, address _safeYieldConfig) Ownable(protocolAdmin) {
        if (_safeYieldConfig == address(0)) revert SYTD__INVALID_ADDRESS();

        configs = ISafeYieldConfigs(_safeYieldConfig);
    }

    function depositReward(address[] calldata rewardAssets, uint128[] calldata amounts) external onlyOwner {
        if (rewardAssets.length != amounts.length) revert SYTD__LENGTH_MISMATCH();

        for (uint256 i; i < rewardAssets.length; i++) {
            address rewardAsset = rewardAssets[i];
            uint128 amount = amounts[i];

            if (rewardAsset == address(0)) revert SYTD__INVALID_ADDRESS();
            if (amount == 0) continue;

            RewardToken storage rewardToken = rewardTokens[rewardAsset];

            if (!rewardToken.isRewardToken) {
                rewardToken.isRewardToken = true;
                allRewardTokens.push(rewardAsset);
            }

            IERC20(rewardAsset).safeTransferFrom(msg.sender, address(this), amount);

            rewardToken.accRewardPerShare += (amount * DIVISION_FACTOR) / configs.safeYieldStaking().totalStaked();

            emit RewardDeposited(msg.sender, rewardAsset, amount);
        }
    }

    function handleActionBefore(address _user, bytes4 _selector) external override onlyStaking { }

    function handleActionAfter(address _user, bytes4 _selector) external override onlyStaking {
        uint256 _userBalance = IERC20(address(configs.safeYieldStaking())).balanceOf(_user);
        uint256 _userLastsSayBalance = lastStakeBalance[_user];

        emit HandleActionAfter(_user, _selector);

        if (_userBalance > _userLastsSayBalance) {
            //staking
            uint256 _deposit = _userBalance - _userLastsSayBalance;

            address[] memory _rewardTokens = allRewardTokens;
            for (uint256 i; i < _rewardTokens.length; i++) {
                address _rewardToken = _rewardTokens[i];
                uint256 _accRewardPerShare = rewardTokens[_rewardToken].accRewardPerShare;

                userTokenRewardDebt[_user][_rewardToken] += int256(_calculateAccRewards(_accRewardPerShare, _deposit));
            }
            lastStakeBalance[_user] = _userBalance;
        } else if (_userBalance < _userLastsSayBalance) {
            //unstaking
            uint256 _withdrawn = _userLastsSayBalance - _userBalance;

            address[] memory _rewardTokens = allRewardTokens;

            for (uint256 i; i < _rewardTokens.length; i++) {
                address _rewardToken = _rewardTokens[i];
                uint256 _accRewardPerShare = rewardTokens[_rewardToken].accRewardPerShare;

                userTokenRewardDebt[_user][_rewardToken] -= int256(_calculateAccRewards(_accRewardPerShare, _withdrawn));
            }

            lastStakeBalance[_user] = _userBalance;
        }
    }

    function claimRewards(address rewardAsset) external override {
        if (rewardAsset == address(0)) revert SYTD__INVALID_ADDRESS();

        uint256 _pendingReward = pendingRewards(msg.sender, rewardAsset);

        if (_pendingReward != 0) {
            userTokenRewardDebt[msg.sender][rewardAsset] =
                int256(_calculateAccRewards(rewardTokens[rewardAsset].accRewardPerShare, lastStakeBalance[msg.sender]));

            IERC20(rewardAsset).safeTransfer(msg.sender, _pendingReward);

            emit RewardsClaimed(msg.sender, rewardAsset, _pendingReward);
        }
    }

    function getUserRewardDebt(address user, address rewardAsset) external view override returns (int256) {
        return userTokenRewardDebt[user][rewardAsset];
    }

    function claimAllRewards() external override {
        address[] memory _rewardTokens = allRewardTokens;

        for (uint256 i; i < _rewardTokens.length; i++) {
            address _rewardToken = _rewardTokens[i];

            uint256 _pendingReward = pendingRewards(msg.sender, _rewardToken);

            if (_pendingReward != 0) {
                userTokenRewardDebt[msg.sender][_rewardToken] = int256(
                    _calculateAccRewards(rewardTokens[_rewardToken].accRewardPerShare, lastStakeBalance[msg.sender])
                );

                IERC20(_rewardToken).safeTransfer(msg.sender, _pendingReward);

                emit RewardsClaimed(msg.sender, _rewardToken, _pendingReward);
            }
        }
    }

    function pendingRewards(address user, address rewardAsset) public view returns (uint256) {
        uint256 _accRewardPerShare = rewardTokens[rewardAsset].accRewardPerShare;

        return uint256(
            int256(_calculateAccRewards(_accRewardPerShare, lastStakeBalance[user]))
                - userTokenRewardDebt[user][rewardAsset]
        );
    }

    function allPendingRewards(address user) external view override returns (Rewards[] memory) {
        address[] memory _rewardTokens = allRewardTokens;
        uint256 tokenCount = _rewardTokens.length;

        Rewards[] memory _pendingRewards = new Rewards[](tokenCount);

        for (uint256 i; i < tokenCount; i++) {
            address _rewardToken = _rewardTokens[i];

            uint256 _rewards = pendingRewards(user, _rewardToken);

            _pendingRewards[i] = Rewards(_rewardToken, _rewards);
        }

        return _pendingRewards;
    }

    function retrieve(address token, uint256 amount) external override onlyOwner {
        if ((address(this).balance) != 0) {
            payable(owner()).transfer(address(this).balance);
        }

        IERC20(token).transfer(owner(), amount);
    }

    function getRewardTokens(address yieldAsset) external view returns (RewardToken memory) {
        return rewardTokens[yieldAsset];
    }

    function getAllRewardTokens() external view override returns (address[] memory) {
        return allRewardTokens;
    }

    function getLastStakeBalance(address user) external view returns (uint256) {
        return lastStakeBalance[user];
    }

    function existingLastStakeBalance(address user) public view returns (uint256) {
        return lastStakeBalance[user] != 0
            ? lastStakeBalance[user]
            : IERC20(address(configs.safeYieldStaking())).balanceOf(user);
    }

    function _calculateAccRewards(uint256 _accRewardPerShare, uint256 _amount) private pure returns (uint256) {
        return (_amount * _accRewardPerShare) / DIVISION_FACTOR;
    }
}
