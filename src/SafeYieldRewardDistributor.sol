// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISafeYieldPreSale } from "./interfaces/ISafeYieldPreSale.sol";
import { ISafeToken } from "./interfaces/ISafeToken.sol";
import { StakingEmissionState, PreSaleState, ContractShare } from "./types/SafeTypes.sol";
import { ISafeYieldRewardDistributor } from "./interfaces/ISafeYieldRewardDistributor.sol";
//import {console} from "forge-std/Test.sol";

contract SafeYieldRewardDistributor is ISafeYieldRewardDistributor, Ownable2Step {
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
    ISafeYieldPreSale public safePresale;
    StakingEmissionState public currentStakingState;

    address public teamOperations;
    address public usdcBuyback;
    address public safeStaking;
    uint256 public safeMinted;

    uint256 public accumulatedUsdcPerContract;
    uint256 public lastBalance;
    uint48 public lastUpdatedTimestamp;

    mapping(address contract_ => uint256 index) public contractIndex;
    mapping(address contract_ => uint256 outstanding) public outStandingContractRewards;
    mapping(address => int256) public shareDebt;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ContractAdded(address indexed contract_, uint16 indexed share);
    event ContractRemoved(address indexed contract_);
    event SafeStakingUpdated(address indexed previousStaking, address indexed newStaking);
    event TeamOperationsUpdated(address indexed previousTeamOperations, address indexed newTeamOperations);
    event UsdcBuybackUpdated(address indexed previousUsdcBuyback, address indexed newUsdcBuyback);

    event RewardDistributed(address indexed contract_, uint256 indexed usdcDistributed);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SYRD__NOT_ADMIN_OR_VALID_CONTRACT();
    error SYRD__MAX_SUPPLY_NOT_EXCEEDED();
    error SYRD__ARRAY_LENGTH_MISMATCH();
    error SYRD__DUPLICATE_CONTRACT();
    error SYRD__INVALID_CONTRACT();
    error SYRD__TRANSFER_FAILED();
    error SYRD__INVALID_SHARE();
    error SYRD__ZERO_ADDRESS();
    error SYRD__INVALID_BPS();

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
        address _protocolAdmin
    ) Ownable(_protocolAdmin) {
        if (
            _usdcToken == address(0) || _safeToken == address(0) || _teamOperations == address(0)
                || _usdcBuyback == address(0) || _safeStaking == address(0) || _protocolAdmin == address(0)
        ) {
            revert SYRD__ZERO_ADDRESS();
        }

        safeToken = ISafeToken(_safeToken);
        usdcToken = IERC20(_usdcToken);

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

        ///@dev cannot remove the first two contracts
        if (index < 2) revert SYRD__INVALID_CONTRACT();

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
     * @notice returns all the contracts that are eligible for rewards.
     * @return all the contracts that are eligible for rewards.
     */
    function getAllContracts() external view override returns (ContractShare[] memory) {
        return approvedContracts;
    }

    /**
     * @notice returns reward details for a contract.
     * @param contract_ the address of the contract to get details for.
     * @return usdcDistributed rewards distributed to the contract.
     */
    function distributeToContract(address contract_) public override returns (uint256 usdcDistributed) {
        if (msg.sender != owner() && msg.sender != contract_) {
            revert SYRD__NOT_ADMIN_OR_VALID_CONTRACT();
        }

        updateAllocations();

        ContractShare memory contractDetails = approvedContracts[contractIndex[contract_]];
        if (contractDetails.contract_ != contract_) {
            revert SYRD__INVALID_CONTRACT();
        }

        int256 accumulatedContractUsdc = SafeCast.toInt256(contractDetails.share * (accumulatedUsdcPerContract));

        // console.log("Contract share %s", contractDetails.share);
        // console.log(
        //     "accumulatedContractUsdc %s",
        //     uint256(accumulatedContractUsdc)
        // );

        usdcDistributed = SafeCast.toUint256(accumulatedContractUsdc - contractDetails.shareDebt);

        usdcDistributed += outStandingContractRewards[contract_];
        outStandingContractRewards[contract_] = 0;

        if (usdcDistributed != 0) {
            approvedContracts[contractIndex[contract_]].shareDebt = accumulatedContractUsdc;
            lastBalance = usdcToken.balanceOf(address(this)) - usdcDistributed;
        }

        if (currentStakingState == StakingEmissionState.Live && safeMinted < MAX_STAKING_EMISSIONS) {
            if (contract_ == safeStaking) {
                //console.log("usdcToDistribute %s", usdcDistributed);

                uint256 tokensToMint = ((usdcDistributed * 1e18) / _getCurrentTokenPrice());

                safeToken.mint(contract_, tokensToMint);

                // console.log("Minted %s tokens to %s", tokensToMint, safeMinted);
                safeMinted += tokensToMint;

                emit RewardDistributed(contract_, tokensToMint);
                return tokensToMint;
            }
        }
        if (!usdcToken.transfer(contract_, usdcDistributed)) {
            revert SYRD__TRANSFER_FAILED();
        }
        emit RewardDistributed(contract_, usdcDistributed);
    }

    /**
     * @notice switches the shares per phase.
     * @dev If the staking emissions have started, the shares will be updated to 35% for $SAFE stakers,
     * 30% for team operations, and 35% for USDC buybacks.
     * If the staking emissions have ended, the shares will be updated to 60% for $SAFE stakers,
     * 30% for team operations, and 10% for USDC buybacks.
     */
    function switchSharesPerPhase() public override {
        ContractShare[] memory _contractShares = new ContractShare[](3);
        if (currentStakingState == StakingEmissionState.Live && safeMinted < MAX_STAKING_EMISSIONS) {
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

    /// @dev Starts the staking emissions.
    function startStakingEmissions() public override onlyOwner {
        currentStakingState = StakingEmissionState.Live;

        switchSharesPerPhase();
    }

    /// @dev Ends the staking emissions.
    function endStakingEmissions() public override onlyOwner {
        //!note keep this?
        // if (safeMinted < MAX_STAKING_EMISSIONS)
        //     revert SYRD__MAX_SUPPLY_NOT_EXCEEDED();
        currentStakingState = StakingEmissionState.Ended;

        switchSharesPerPhase();
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

    /// @dev Removes excess USDC from the contract.
    function removeExcessUsdc(uint256 amount) public override onlyOwner {
        if (!usdcToken.transfer(owner(), amount)) {
            revert SYRD__TRANSFER_FAILED();
        }
    }

    /// @dev Returns the pending rewards for a contract.
    function pendingRewards(address contract_) public view override returns (uint256) {
        if (contract_ != approvedContracts[contractIndex[contract_]].contract_) {
            return 0;
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

        // currentStakingState == StakingEmissionState.Live &&

        /**
         * uint256 tokensToMint = ((usdcDistributed * 1e18) /
         *                 _getCurrentTokenPrice());
         */
        uint256 pendingContractRewards = pendingContractUsdc + outStandingContractRewards[contract_];

        if (currentStakingState == StakingEmissionState.Live) {
            if (contract_ == safeStaking) {
                pendingContractRewards = ((pendingContractRewards * 1e18) / _getCurrentTokenPrice());
                return pendingContractRewards;
            }
        }

        return pendingContractRewards;
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
                outStandingContractRewards[contractDetails.contract_] += usdcDistributed;
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

    /// @dev Internal function to get the current token price.
    function _getCurrentTokenPrice() internal pure returns (uint256) {
        return 1e6; //@note : implement logic to get the current token price
    }
}
