// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PreSaleState } from "../types/SafeTypes.sol";

interface ISafeYieldPreSale {
    function currentPreSaleState() external view returns (PreSaleState);

    function deposit(uint128 usdcAmount, bytes32 referrerId) external;

    function claimSafeTokens() external;

    function safeTokensAvailable() external view returns (uint128);

    function redeemUsdcCommission() external;

    function setTokenPrice(uint128 _price) external;

    function getReferrerID() external view returns (bytes32);

    function setProtocolMultisig(address _protocolMultisig) external;

    function setReferrerCommissionBps(uint128 _commissionUsdc, uint128 _commissionSafe) external;

    function calculateSafeTokens(uint128 usdcAmount) external view returns (uint128);

    function mintPreSaleAllocation() external;

    function pause() external;

    function unpause() external;

    function startPresale() external;

    function endPresale() external;

    function getTotalSafeTokensOwed(address user) external view returns (uint128);

    function setAllocationsPerWallet(uint128 _min, uint128 _max) external;
}
