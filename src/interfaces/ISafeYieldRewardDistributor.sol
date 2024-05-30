// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ContractShare, StakingEmissionState } from "../types/SafeTypes.sol";

interface ISafeYieldRewardDistributor {
    function currentStakingState() external view returns (StakingEmissionState);

    function withdrawStakingUsdc() external;

    function isSafeRewardsDistributed() external view returns (bool);

    function updateSafeStaking(address newSafeStaking) external;

    function updateTeamOperations(address newTeamOperations) external;

    function updateUsdcBuyback(address newUsdcBuyback) external;

    function addContract(ContractShare memory newContractInfo, ContractShare[] memory updatedAllocations) external;

    function removeContract(address contract_, ContractShare[] memory updatedAllocations) external;

    function getAllContracts() external view returns (ContractShare[] memory);

    function distributeToContract(address contract_) external returns (uint256 usdcDistributed);

    function switchSharesPerPhase() external;

    function pendingRewards(address contract_) external view returns (uint256, uint256);

    function updateAllocations() external;

    function startStakingEmissions() external;

    function endStakingEmissions() external;

    function updateContractShares(ContractShare[] memory updatedAllocations) external;

    function removeExcessUsdc(uint256 amount) external;

    function mintAllAllocations() external;
}
