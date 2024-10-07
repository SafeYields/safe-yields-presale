// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { PreSaleState } from "src/types/SafeTypes.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";

contract SafeYieldAirdropTest is SafeYieldBaseTest {
    function testStakeAndVest() public {
        vm.prank(protocolAdmin);
        presale.transferRemainingSayToken(address(airdrop));

        bytes32[] memory aliceMerkleProof = new bytes32[](2);
        aliceMerkleProof[0] = 0x2eaff8d51273cf94a9fc990c007506ea709ab23f02d96f0516a28485c0a9f939;
        aliceMerkleProof[1] = 0x4f01082713464f7c40bfbee4e6ba188f5bef2330333144897af4c0573eab09a1;

        vm.prank(ALICE);
        airdrop.stakeAndVestSayTokens(1000e18, aliceMerkleProof);
    }
}
