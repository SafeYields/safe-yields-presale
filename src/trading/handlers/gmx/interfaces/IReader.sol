// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { PositionProps } from "../types/PositionTypes.sol";
import { OrderProps } from "../types/OrderTypes.sol";

interface IReader {
    function getAccountPositions(address dataStore, address account, uint256 start, uint256 end)
        external
        view
        returns (PositionProps[] memory);

    // function getPositionPnlUsd(
    //     DataStore dataStore,
    //     Market.Props memory market,
    //     MarketUtils.MarketPrices memory prices,
    //     Position.Props memory position,
    //     uint256 sizeDeltaUsd
    // ) public view returns (int256, int256, uint256);

    // function getPositionInfo(
    //     IDataStore dataStore,
    //     IReferralStorage referralStorage,
    //     bytes32 positionKey,
    //     MarketPrices memory prices,
    //     uint256 sizeDeltaUsd,
    //     address uiFeeReceiver,
    //     bool usePositionSizeAsSizeDeltaUsd
    // ) public view returns (ReaderUtils.PositionInfo memory);

    function getOrder(address dataStore, bytes32 key) external view returns (OrderProps memory);

    function getPosition(address dataStore, bytes32 key) external view returns (PositionProps memory);
}
