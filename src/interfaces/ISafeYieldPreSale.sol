// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {PreSaleState} from "../types/SafeTypes.sol";
interface ISafeYieldPreSale {
    function preSaleState() external view returns (PreSaleState);

    function deposit(
        address investor,
        uint128 usdcAmount,
        bytes32 referrerId
    ) external;

    function claimSafeTokens() external;

    function withdrawUSDC(address receiver, uint256 amount) external;

    function redeemUsdcCommission() external;

    function createReferrerId() external returns (bytes32 referrerId);

    function setTokenPrice(uint128 _price) external;

    function setReferrerCommission(
        uint128 _commissionUsdc,
        uint128 _commissionSafe
    ) external;

    function calculateSafeTokens(
        uint128 usdcAmount
    ) external view returns (uint128);

    function pause() external;

    function unpause() external;

    function startPresale() external;

    function endPresale() external;

    function getTotalSafeTokensOwed(
        address user
    ) external view returns (uint128);

    function setAllocations(uint128 _min, uint128 _max) external;
}
