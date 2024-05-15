// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {PreSaleState} from "../types/SafeTypes.sol";
interface ISafeYieldPreSale {
    function preSaleState() external view returns (PreSaleState);

    function buy(address user, uint128 usdcAmount) external;

    function buyWithReferrer(
        address user,
        uint128 usdcAmount,
        address referrerAddress
    ) external;

    function claim() external;

    function setTokenPrice(uint128 _price) external;

    function setReferrerCommission(
        uint128 _commissionUsdc,
        uint128 _commissionSafe
    ) external;

    // function calculatesSafeTokens(
    //     uint128 usdcAmount
    // ) external view returns (uint128);
    function calculatesSafeTokensAvailable() external view returns (uint128);

    function pause() external;

    function unpause() external;

    function startPresale() external;

    function endPresale() external;

    // function calculateReferrerCommissionSafe(
    //     uint128 safeTokens
    // ) external view returns (uint128);

    // function calculateReferrerCommissionUsdc(
    //     uint128 usdcAmount
    // ) external view returns (uint128);

    function getTotalSafeTokensOwed(
        address user
    ) external view returns (uint128);

    function setAllocations(uint128 _min, uint128 _max) external;

    function depositSafeTokens(uint128 amount, address owner_) external;

    function withdrawUSDC(address receiver) external;
}
