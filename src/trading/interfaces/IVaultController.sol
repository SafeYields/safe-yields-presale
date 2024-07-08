// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { UserDepositStats, StrategyStats } from "src/types/SafeTypes.sol";

interface IVaultController {
    function deposit(uint128 amount) external;

    function calculatePNL(address user) external view returns (int256 pendingPnl);

    function claimPnl() external returns (int256 pnl);

    function supplyFunds(uint16 strategyId, uint128 amount) external;

    function numberStrategiesActive() external view returns (StrategyStats[] memory strategiesActive);

    function activeUserStats(address user) external view returns (UserDepositStats memory userDeposits);

    function userCurrentUtilizations(address user, uint8 strategyId)
        external
        view
        returns (uint128 amountUtilizedPerStrategy);
}
