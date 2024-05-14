// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

struct ReferrerVolume {
    uint128 usdcVolume;
    uint128 safeTokenVolume;
}

enum PreSaleState {
    NotStarted,
    Live,
    Ended
}

enum StakingEmissionState {
    NotStarted,
    Live, //STAKE
    Ended //USDC
}

struct ContractShare {
    int256 shareDebt;
    address contract_;
    uint16 share;
}
