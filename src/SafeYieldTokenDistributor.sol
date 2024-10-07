//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { RewardToken } from "./types/SafeTypes.sol";
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
    ISafeYieldStaking public staking;
    mapping(address user => mapping(address rewardToken => int256 rewardDebt)) public userTokenRewardDebt;
    mapping(address user => uint256 stakeBalance) public lastStakeBalance;
    mapping(address rewardToken => RewardToken) public rewardTokens;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RewardDeposited(address indexed owner, address indexed rewardAsset, uint256 indexed amount);

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
        if (msg.sender != address(staking)) revert SYTD__UNAUTHORIZED();
        _;
    }

    constructor(address protocolAdmin, address _staking) Ownable(protocolAdmin) {
        if (_staking == address(0)) revert SYTD__INVALID_ADDRESS();

        staking = ISafeYieldStaking(_staking);
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

            rewardToken.accRewardPerShare += (amount * DIVISION_FACTOR) / staking.totalStaked();

            emit RewardDeposited(msg.sender, rewardAsset, amount);
        }
    }

    function handleActionBefore(address _user, bytes4 _selector) external override onlyStaking { }

    function handleActionAfter(address _user, bytes4 _selector) external override onlyStaking {
        uint256 _userBalance = IERC20(address(staking)).balanceOf(_user);
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

            ///NB: @dev if a user trigger an operation which would reduce their bPls balance, should we claim their rewards?

            address[] memory _rewardTokens = allRewardTokens;

            for (uint256 i; i < _rewardTokens.length; i++) {
                address _rewardToken = _rewardTokens[i];
                uint256 _accRewardPerShare = rewardTokens[_rewardToken].accRewardPerShare;

                userTokenRewardDebt[_user][_rewardToken] -= int256(_calculateAccRewards(_accRewardPerShare, _withdrawn));
            }

            lastStakeBalance[_user] = _userBalance;
        }
    }

    function _calculateAccRewards(uint256 _accRewardPerShare, uint256 _amount) private pure returns (uint256) {
        return (_amount * _accRewardPerShare) / DIVISION_FACTOR;
    }
}
