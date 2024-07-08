// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.26;

// import { IDataStore } from "./IDataStore.sol";
// import { Props } from "./types/GMXPositionTypes.sol";
// import { MarketProps } from "./types/GMXMarketTypes.sol";

// interface IGMXStrategyReader {
//     // /**
//     //  * @return Props Position props
//     //  */
//     // function getPosition(IDataStore dataStore, bytes32 key) external view returns (Props memory);

//     // /**
//     //  * @return Props Order props
//     //  */
//     // function getOrder(IDataStore dataStore, bytes32 key) external view returns (Props memory);

//     // function getPositionPnlUsd(
//     //     IDataStore dataStore,
//     //     MarketProps memory market,
//     //     MarketUtils.MarketPrices memory prices,
//     //     bytes32 positionKey,
//     //     uint256 sizeDeltaUsd
//     // ) external view returns (int256, int256, uint256);

//     // function getAccountPositions(IDataStore dataStore, address account, uint256 start, uint256 end)
//     //     external
//     //     view
//     //     returns (Position.Props[] memory);

//     // function getAccountOrders(IDataStore dataStore, address account, uint256 start, uint256 end)
//     //     external
//     //     view
//     //     returns (Order.Props[] memory);

//     // function getAccountPositionInfoList(
//     //     IDataStore dataStore,
//     //     IReferralStorage referralStorage,
//     //     bytes32[] memory positionKeys,
//     //     MarketUtils.MarketPrices[] memory prices,
//     //     address uiFeeReceiver
//     // ) external view returns (ReaderUtils.PositionInfo[] memory);

//     // function getPositionInfo(
//     //     IDataStore dataStore,
//     //     IReferralStorage referralStorage,
//     //     bytes32 positionKey,
//     //     MarketUtils.MarketPrices memory prices,
//     //     uint256 sizeDeltaUsd,
//     //     address uiFeeReceiver,
//     //     bool usePositionSizeAsSizeDeltaUsd
//     // ) external view returns (ReaderUtils.PositionInfo memory);

//     // function getDepositAmountOut(
//     //     IDataStore dataStore,
//     //     Market.Props memory market,
//     //     MarketUtils.MarketPrices memory prices,
//     //     uint256 longTokenAmount,
//     //     uint256 shortTokenAmount,
//     //     address uiFeeReceiver,
//     //     ISwapPricingUtils.SwapPricingType swapPricingType,
//     //     bool includeVirtualInventoryImpact
//     // ) external view returns (uint256);

//     // function getWithdrawalAmountOut(
//     //     IDataStore dataStore,
//     //     Market.Props memory market,
//     //     MarketUtils.MarketPrices memory prices,
//     //     uint256 marketTokenAmount,
//     //     address uiFeeReceiver,
//     //     ISwapPricingUtils.SwapPricingType swapPricingType
//     // ) external view returns (uint256, uint256);
// }
