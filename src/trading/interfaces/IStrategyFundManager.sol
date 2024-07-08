// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { UserDepositDetails } from "../types/StrategyControllerTypes.sol";

interface IStrategyFundManager {
    function deposit(uint128 amount) external;

    function withdraw(uint128 amount) external;

    function claimProfit() external returns (int256 pnl);

    function setStrategyController(address _controller) external;

    function fundStrategy(uint256 amountRequested) external returns (uint256 totalDepositsAvailable);

    function pendingRewards(address user) external view returns (int256 pendingPnl);

    function userDepositDetails(address user) external view returns (UserDepositDetails memory userDeposits);

    function userCurrentUtilizations(address user, uint8 strategyId)
        external
        view
        returns (uint128 amountUtilizedPerStrategy);
}
