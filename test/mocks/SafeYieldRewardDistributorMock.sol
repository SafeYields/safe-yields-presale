// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";

contract SafeYieldRewardDistributorMock is SafeYieldRewardDistributor {
    /**
     * distributor = new SafeYieldRewardDistributor(
     *             address(safeToken), address(usdc), teamOperations, usdcBuyback, address(staking), address(twap)
     *         );
     */
    constructor(address safe, address usdc, address Operations, address usdcBuyBack, address staking, address twap)
        SafeYieldRewardDistributor(safe, usdc, Operations, usdcBuyBack, staking, twap)
    { }

    function setSafeTransferred(uint256 amountTransferred) external onlyOwner {
        safeTransferred = amountTransferred;
    }
}
