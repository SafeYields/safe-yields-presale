// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { StakingEmissionState, ContractShare } from "./types/SafeTypes.sol";
import { ISafeYieldRewardDistributor } from "./interfaces/ISafeYieldRewardDistributor.sol";
import { SafeYieldTWAP } from "./SafeYieldTWAP.sol";
import { ISafeYieldStaking } from "./interfaces/ISafeYieldStaking.sol";

contract SafeYieldRewardDistributor is ISafeYieldRewardDistributor, Ownable2Step {
    using SafeERC20 for IERC20;
    using SafeERC20 for ISafeToken;
    /*//////////////////////////////////////////////////////////////
                      IMMUTABLES & CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint16 public constant BPS_MAX = 10_000;
    uint256 public constant MAX_STAKING_EMISSIONS = 11_000_000e18;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISafeToken public safeToken;
    IERC20 public usdcToken;
    ContractShare[] public approvedContracts;
    StakingEmissionState public currentStakingState;
    SafeYieldTWAP public safeYieldTWAP;

    bool public isSafeRewardsDistributed;

    address public teamOperations;
    address public usdcBuyback;
    address public safeStaking;
    /**
     *
     * @dev the address of the pool to get the TWAP from.
     * pool should be SAFE/WETH, since we using safe price
     * in terms of WETH.
     */
    address public safeYieldPool;

    uint256 public safeTransferred;
    uint256 public totalUsdcFromSafeMinting;
    uint256 public accumulatedUsdcPerContract;
    uint256 public lastBalance;
    uint48 public lastUpdatedTimestamp;
    uint32 public twapInterval = 1800 seconds; // 30 minutes

    mapping(address contract_ => uint256 index) public contractIndex;
    mapping(address contract_ => uint256 outstanding) public outStandingContractRewards;
    mapping(address => int256) public shareDebt;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ContractAdded(address indexed contract_, uint16 indexed share);
    event ContractRemoved(address indexed contract_);
    event StakingEmissionsStarted();
    event StakingEmissionsEnded();
    event AllAllocationsMinted(uint256 indexed amount);
    event SafeStakingUpdated(address indexed previousStaking, address indexed newStaking);
    event TeamOperationsUpdated(address indexed previousTeamOperations, address indexed newTeamOperations);
    event UsdcBuybackUpdated(address indexed previousUsdcBuyback, address indexed newUsdcBuyback);
    event UsdcWithdrawn(address indexed recipient, uint256 indexed amount);
    event RewardDistributed(address indexed contract_, uint256 indexed rewardsDistributed);
    event TokensRecovered(address indexed token, uint256 indexed amount);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SYRD__NOT_ADMIN_OR_VALID_CONTRACT();
    error SYRD__STAKING_EMISSION_NOT_EXHAUSTED();
    error SYRD__ARRAY_LENGTH_MISMATCH();
    error SYRD__TOKEN_NOT_ALLOWED();
    error SYRD__DUPLICATE_CONTRACT();
    error SYRD__INVALID_CONTRACT();
    error SYRD__TRANSFER_FAILED();
    error SYRD__INVALID_SHARE();
    error SYRD__ZERO_ADDRESS();
    error SYRD__INVALID_BPS();
    error SYRD__INVALID_TWAP_PERIOD();

    /**
     * Three Phase :
     * 0. Pre-sale to Launch rewards distributed in USDC.
     * 60% of the rewards will be distributed to $SAFE stakers.
     * 30% of the rewards will be used for team operations.
     * 10% of the rewards will be used for USDC buybacks and burns.
     *
     * 1. During Staking Emissions:
     * 35% of the rewards will be distributed to $SAFE stakers.
     * 30% of the rewards will be used for team operations.
     * 35% of the rewards will be used for USDC buybacks and burns.
     *
     * 2. After Staking Emissions:
     * 60% of the rewards will be distributed to $SAFE stakers.
     * 30% of the rewards will be used for team operations.
     * 10% of the rewards will be used for USDC buybacks and burns.
     */
    constructor(
        address _safeToken,
        address _usdcToken,
        address _teamOperations,
        address _usdcBuyback,
        address _safeStaking,
        address _safeYieldTWAP
    ) Ownable(msg.sender) {
        if (
            _usdcToken == address(0) || _safeToken == address(0) || _teamOperations == address(0)
                || _usdcBuyback == address(0) || _safeStaking == address(0) || _safeYieldTWAP == address(0)
        ) {
            revert SYRD__ZERO_ADDRESS();
        }

        safeToken = ISafeToken(_safeToken);
        usdcToken = IERC20(_usdcToken);
        safeYieldTWAP = SafeYieldTWAP(_safeYieldTWAP);

        teamOperations = _teamOperations;
        usdcBuyback = _usdcBuyback;
        safeStaking = _safeStaking;

        approvedContracts.push(ContractShare(0, teamOperations, 3_000));
        approvedContracts.push(ContractShare(0, safeStaking, 6_000));
        approvedContracts.push(ContractShare(0, usdcBuyback, 1_000));

        contractIndex[teamOperations] = 0;
        contractIndex[safeStaking] = 1;
        contractIndex[usdcBuyback] = 2;
    }

    /**
     * @notice allows admin to add a new recipient of fees.
     * @param newContractInfo the details of the new contract
     * @param updatedAllocations the new allocations for the previous contracts
     */
    function addContract(ContractShare memory newContractInfo, ContractShare[] memory updatedAllocations)
        external
        override
        onlyOwner
    {
        if (newContractInfo.contract_ == address(0)) {
            revert SYRD__ZERO_ADDRESS();
        }
        if (updatedAllocations.length != approvedContracts.length) {
            revert SYRD__ARRAY_LENGTH_MISMATCH();
        }
        if (newContractInfo.share == 0) revert SYRD__INVALID_SHARE();

        uint256 index = contractIndex[newContractInfo.contract_];

        if (index != 0 || newContractInfo.contract_ == approvedContracts[0].contract_) {
            revert SYRD__DUPLICATE_CONTRACT();
        }

        _distributeToAllContracts();

        uint256 updateLength = updatedAllocations.length;
        uint16 totalShare = newContractInfo.share;
        uint256 i;

        for (; i < updateLength; ++i) {
            ///@dev should be updated in the same order as approvedContracts
            if (approvedContracts[i].contract_ != updatedAllocations[i].contract_) {
                revert SYRD__INVALID_CONTRACT();
            }
            if (approvedContracts[i].share != updatedAllocations[i].share) {
                approvedContracts[i].share = updatedAllocations[i].share;
                approvedContracts[i].shareDebt =
                    SafeCast.toInt256(updatedAllocations[i].share * accumulatedUsdcPerContract);
            }

            totalShare += updatedAllocations[i].share;
        }
        if (totalShare != BPS_MAX) revert SYRD__INVALID_BPS();

        contractIndex[newContractInfo.contract_] = approvedContracts.length;
        newContractInfo.shareDebt = SafeCast.toInt256(newContractInfo.share * accumulatedUsdcPerContract);
        approvedContracts.push(newContractInfo);

        emit ContractAdded(newContractInfo.contract_, newContractInfo.share);
    }

    /**
     * @notice allows admin to remove a recipient of fees.
     * @param contract_ the address of the contract to remove
     * @param updatedAllocations the new allocations for the previous contracts
     */
    function removeContract(address contract_, ContractShare[] memory updatedAllocations) external override onlyOwner {
        if (contract_ == address(0)) revert SYRD__ZERO_ADDRESS();
        if (updatedAllocations.length != approvedContracts.length) {
            revert SYRD__ARRAY_LENGTH_MISMATCH();
        }

        uint256 index = contractIndex[contract_];

        if (updatedAllocations[index].share != 0) revert SYRD__INVALID_SHARE();

        ///@dev cannot remove the first three contracts
        if (index < 3) revert SYRD__INVALID_CONTRACT();

        _distributeToAllContracts();
        distributeToContract(contract_);

        uint256 updateLength = updatedAllocations.length;
        uint256 totalShare;
        uint256 i;

        for (; i < updateLength; ++i) {
            ///@dev skip the removed contract
            if (approvedContracts[i].contract_ == contract_) continue;

            ///@dev should be updated in the same order as approvedContracts
            if (approvedContracts[i].contract_ != updatedAllocations[i].contract_) {
                revert SYRD__INVALID_CONTRACT();
            }

            if (approvedContracts[i].share != updatedAllocations[i].share) {
                approvedContracts[i].share = updatedAllocations[i].share;
                approvedContracts[i].shareDebt =
                    SafeCast.toInt256(updatedAllocations[i].share * accumulatedUsdcPerContract);
            }
            totalShare += updatedAllocations[i].share;
        }

        if (totalShare != BPS_MAX) revert SYRD__INVALID_BPS();

        uint256 lastContractIndex = approvedContracts.length - 1;
        ContractShare memory lastContract = approvedContracts[lastContractIndex];

        delete contractIndex[contract_];
        if (lastContractIndex != index) {
            contractIndex[lastContract.contract_] = index;
            approvedContracts[index] = lastContract;
        }
        approvedContracts.pop();

        emit ContractRemoved(contract_);
    }

    function updateSafeStaking(address newSafeStaking) external override onlyOwner {
        _updateContract(newSafeStaking, safeStaking);
        emit SafeStakingUpdated(safeStaking, newSafeStaking);
        safeStaking = newSafeStaking;
    }

    function updateTeamOperations(address newTeamOperations) external override onlyOwner {
        _updateContract(newTeamOperations, teamOperations);
        emit TeamOperationsUpdated(teamOperations, newTeamOperations);
        teamOperations = newTeamOperations;
    }

    function updateUsdcBuyback(address newUsdcBuyback) external override onlyOwner {
        _updateContract(newUsdcBuyback, usdcBuyback);
        emit UsdcBuybackUpdated(usdcBuyback, newUsdcBuyback);
        usdcBuyback = newUsdcBuyback;
    }

    /**
     * @notice withdraws the USDC from the contract.
     * @dev this withdraws the USDC meant for staking rewards,
     * during the staking emissions to the USDC buyback address.
     */
    function withdrawStakingUsdc() external override onlyOwner {
        uint256 withdrawalAmount = totalUsdcFromSafeMinting;

        usdcToken.safeTransfer(usdcBuyback, withdrawalAmount);

        totalUsdcFromSafeMinting = 0;

        emit UsdcWithdrawn(owner(), withdrawalAmount);
    }

    /**
     * @notice allows the owner to recover any token sent to the contract.
     * @param token the address of the token to recover.
     * @param amount the amount of the token to recover.
     */
    function recoverTokens(address token, uint256 amount) external override onlyOwner {
        if (token == address(usdcToken) || token == address(safeToken)) revert SYRD__TOKEN_NOT_ALLOWED();
        IERC20(token).safeTransfer(owner(), amount);

        emit TokensRecovered(token, amount);
    }

    function mintStakingEmissionAllocation(uint256 totalSayAllocated) external override onlyOwner {
        safeToken.mint(totalSayAllocated);

        emit AllAllocationsMinted(totalSayAllocated);
    }

    function updateTwapInterval(uint32 newInterval) external override onlyOwner {
        if (newInterval == 0) revert SYRD__INVALID_TWAP_PERIOD();
        twapInterval = newInterval;
    }

    function updateSafePool(address newSafeYieldPool) external override onlyOwner {
        safeYieldPool = newSafeYieldPool;
    }

    /// @return all the contracts that are eligible for rewards.
    function getAllContracts() external view override returns (ContractShare[] memory) {
        return approvedContracts;
    }

    /**
     * @notice transfers rewards to an approved contract. Callable by the contract itself or the owner.
     * @param contract_ the address of the contract to get details for.
     * @return rewardsDistributed which is the amount of rewards distributed either in $SAFE or USDC.
     */
    function distributeToContract(address contract_) public override returns (uint256 rewardsDistributed) {
        if (msg.sender != owner() && msg.sender != contract_) {
            revert SYRD__NOT_ADMIN_OR_VALID_CONTRACT();
        }

        updateAllocations();

        ContractShare memory contractDetails = approvedContracts[contractIndex[contract_]];
        if (contractDetails.contract_ != contract_) {
            revert SYRD__INVALID_CONTRACT();
        }

        int256 accumulatedContractUsdc = SafeCast.toInt256(contractDetails.share * (accumulatedUsdcPerContract));

        uint256 usdcDistributed = SafeCast.toUint256(accumulatedContractUsdc - contractDetails.shareDebt);
        usdcDistributed += outStandingContractRewards[contract_];
        outStandingContractRewards[contract_] = 0;

        if (usdcDistributed != 0) {
            approvedContracts[contractIndex[contract_]].shareDebt = accumulatedContractUsdc;

            if (contract_ == safeStaking && currentStakingState == StakingEmissionState.Live) {
                if (safeTransferred < MAX_STAKING_EMISSIONS) {
                    uint256 safeTokenPrice = _getTokenPrice();
                    uint256 tokensToTransfer = ((usdcDistributed * 1e30) / safeTokenPrice);

                    if (safeTransferred + tokensToTransfer > MAX_STAKING_EMISSIONS) {
                        tokensToTransfer = MAX_STAKING_EMISSIONS - safeTransferred;

                        uint256 valueOfTokenToTransfer = (tokensToTransfer * safeTokenPrice) / 1e30;
                        uint256 excessSafeUsdc = usdcDistributed - valueOfTokenToTransfer;

                        outStandingContractRewards[contract_] += excessSafeUsdc;

                        usdcDistributed = valueOfTokenToTransfer;

                        ///@dev update the state of the staking emissions
                        currentStakingState = StakingEmissionState.Ended;

                        emit StakingEmissionsEnded();
                    }

                    safeToken.safeTransfer(contract_, tokensToTransfer);

                    safeTransferred += tokensToTransfer;

                    totalUsdcFromSafeMinting += usdcDistributed;

                    isSafeRewardsDistributed = true;

                    emit RewardDistributed(contract_, tokensToTransfer);

                    return rewardsDistributed = tokensToTransfer;
                }
            }
            isSafeRewardsDistributed = false;

            usdcToken.safeTransfer(contract_, usdcDistributed);

            lastBalance -= usdcDistributed;

            emit RewardDistributed(contract_, usdcDistributed);

            return rewardsDistributed = usdcDistributed;
        }

        rewardsDistributed = usdcDistributed;
    }

    /**
     * @notice switches the shares per phase.
     * @dev If the staking emissions have started, the shares will be updated to 35% for $SAFE stakers,
     * 30% for team operations, and 35% for USDC buybacks.
     * If the staking emissions have ended, the shares will be updated to 60% for $SAFE stakers,
     * 30% for team operations, and 10% for USDC buybacks.
     */
    function switchSharesPerPhase() public override onlyOwner {
        ContractShare[] memory _contractShares = new ContractShare[](3);
        if (currentStakingState != StakingEmissionState.Ended) {
            _contractShares[0] = ContractShare(0, teamOperations, 3_000);
            _contractShares[1] = ContractShare(0, safeStaking, 3_500);
            _contractShares[2] = ContractShare(0, usdcBuyback, 3_500);
        } else {
            _contractShares[0] = ContractShare(0, teamOperations, 3_000);
            _contractShares[1] = ContractShare(0, safeStaking, 6_000);
            _contractShares[2] = ContractShare(0, usdcBuyback, 1_000);
        }

        updateContractShares(_contractShares);
    }

    /// @dev Updates the fee allocations and accumulates fees for distribution.
    function updateAllocations() public override {
        if (uint48(block.timestamp) > lastUpdatedTimestamp) {
            uint256 contractBalance = usdcToken.balanceOf(address(this));

            uint256 diff = contractBalance - lastBalance;

            if (diff != 0) {
                accumulatedUsdcPerContract += diff / BPS_MAX;
                lastBalance = contractBalance;
            }
            lastUpdatedTimestamp = uint48(block.timestamp);
        }
    }

    /// @dev Starts the staking emissions of $SAFE tokens.
    function startStakingEmissions() public override onlyOwner {
        currentStakingState = StakingEmissionState.Live;

        switchSharesPerPhase();

        emit StakingEmissionsStarted();
    }

    /// @dev Ends the staking emissions.
    function endStakingEmissions() public override onlyOwner {
        if (safeTransferred < MAX_STAKING_EMISSIONS) {
            revert SYRD__STAKING_EMISSION_NOT_EXHAUSTED();
        }

        currentStakingState = StakingEmissionState.Ended;

        switchSharesPerPhase();

        emit StakingEmissionsEnded();
    }

    /// @dev Updates the shares of the contracts.
    function updateContractShares(ContractShare[] memory updatedAllocations) public override onlyOwner {
        if (updatedAllocations.length != approvedContracts.length) {
            revert SYRD__ARRAY_LENGTH_MISMATCH();
        }

        _distributeToAllContracts();

        uint256 updateLength = updatedAllocations.length;
        uint256 totalShare;
        uint256 i;

        for (; i < updateLength; ++i) {
            ///@dev should be updated in the same order as approvedContracts
            if (approvedContracts[i].contract_ != updatedAllocations[i].contract_) {
                revert SYRD__INVALID_CONTRACT();
            }

            if (approvedContracts[i].share != updatedAllocations[i].share) {
                approvedContracts[i].share = updatedAllocations[i].share;
                approvedContracts[i].shareDebt =
                    SafeCast.toInt256(updatedAllocations[i].share * accumulatedUsdcPerContract);
            }
            totalShare += updatedAllocations[i].share;
        }

        if (totalShare != BPS_MAX) revert SYRD__INVALID_BPS();
    }

    /// @dev Returns the pending rewards for a contract.
    function pendingRewards(address contract_) public view override returns (uint256, uint256) {
        if (contract_ != approvedContracts[contractIndex[contract_]].contract_) {
            return (0, 0);
        }

        uint256 accUsdc = accumulatedUsdcPerContract;

        if (uint48(block.timestamp) > lastUpdatedTimestamp) {
            uint256 contractBalance = usdcToken.balanceOf(address(this));

            uint256 diff = contractBalance - lastBalance;

            if (diff != 0) {
                accUsdc += diff / BPS_MAX;
            }
        }

        ContractShare memory contractDetails = approvedContracts[contractIndex[contract_]];

        int256 accumulatedContractUsdc = SafeCast.toInt256(contractDetails.share * accUsdc);

        uint256 pendingContractUsdc = SafeCast.toUint256(accumulatedContractUsdc - contractDetails.shareDebt);

        uint256 pendingContractRewards = pendingContractUsdc + outStandingContractRewards[contract_];

        uint256 pendingSafeRewards;

        if (currentStakingState == StakingEmissionState.Live) {
            if (contract_ == safeStaking) {
                pendingSafeRewards = ((pendingContractRewards * 1e30) / _getTokenPrice());

                return (0, pendingSafeRewards);
            }
        }

        return (pendingContractRewards, 0);
    }

    /// @dev Distributes rewards to all contracts.
    function _distributeToAllContracts() internal {
        updateAllocations();

        uint256 allContracts = approvedContracts.length;
        uint256 i;

        for (; i < allContracts; ++i) {
            ContractShare memory contractDetails = approvedContracts[i];

            int256 accumulatedContractUsdc =
                SafeCast.toInt256(contractDetails.share * uint256(accumulatedUsdcPerContract));
            uint256 usdcDistributed = uint256(accumulatedContractUsdc - contractDetails.shareDebt);

            if (usdcDistributed != 0) {
                approvedContracts[i].shareDebt = accumulatedContractUsdc;

                if (contractDetails.contract_ == safeStaking) {
                    ///@dev let staking contract handle the pulling of rewards
                    ISafeYieldStaking(safeStaking).updateRewards();
                }
            }
        }
    }

    /// @dev Internal function to update contract address.
    /// @param newAddress The new contract address.
    /// @param oldAddress The old contract address.
    function _updateContract(address newAddress, address oldAddress) internal {
        if (newAddress == address(0)) revert SYRD__ZERO_ADDRESS();

        uint256 index = contractIndex[oldAddress];

        approvedContracts[index].contract_ = newAddress;
        contractIndex[newAddress] = index;
        delete contractIndex[oldAddress];
    }

    /// @dev Internal function to get the TWAP $SAFE token price from uniV3.
    function _getTokenPrice() internal view returns (uint256) {
        if (safeYieldPool == address(0)) return 1e18;

        return safeYieldTWAP.getEstimateAmountOut(safeYieldPool, address(safeToken), 1e18, twapInterval);
    }
}
