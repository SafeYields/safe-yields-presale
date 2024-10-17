// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { SafeYieldAirdrop } from "src/SafeYieldAirdrop.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";

contract SafeYieldAirdropTest is SafeYieldBaseTest {
    function testShouldFailIfAmountIsZero() public {
        bytes32[] memory aliceMerkleProof = new bytes32[](2);

        vm.startPrank(ALICE);
        vm.expectRevert(SafeYieldAirdrop.SYA__INVALID_AMOUNT.selector);
        airdrop.stakeAndVestSayTokens(0, aliceMerkleProof);
    }

    function testShouldFailIfMerkleProofIsInvalid() public {
        bytes32[] memory aliceMerkleProof = new bytes32[](0);

        vm.startPrank(ALICE);
        vm.expectRevert(SafeYieldAirdrop.SYA__INVALID_PROOF_LENGTH.selector);
        airdrop.stakeAndVestSayTokens(1000e18, aliceMerkleProof);
    }

    function testShouldFailIfUserAlreadyClaimed() public {
        //end presale
        vm.startPrank(protocolAdmin);
        presale.endPresale();
        vm.stopPrank();

        vm.prank(protocolAdmin);
        presale.transferRemainingSayToken(address(airdrop));

        bytes32[] memory aliceMerkleProof = new bytes32[](2);
        aliceMerkleProof[0] = 0x2eaff8d51273cf94a9fc990c007506ea709ab23f02d96f0516a28485c0a9f939;
        aliceMerkleProof[1] = 0x4f01082713464f7c40bfbee4e6ba188f5bef2330333144897af4c0573eab09a1;

        skip(5 minutes);

        vm.prank(ALICE);
        airdrop.stakeAndVestSayTokens(1_000e18, aliceMerkleProof);

        skip(5 days);

        vm.prank(ALICE);
        vm.expectRevert(SafeYieldAirdrop.SYA__TOKENS_CLAIMED.selector);
        airdrop.stakeAndVestSayTokens(1_000e18, aliceMerkleProof);
    }

    function testShouldFailIfCallerHasInvalidClaim() public {
        bytes32[] memory aliceMerkleProof = new bytes32[](2);
        aliceMerkleProof[0] = 0x2eaff8d51273cf94a9fc990c007506ea709ab23f02d96f0516a28485c0a9f939;
        aliceMerkleProof[1] = 0x4f01082713464f7c40bfbee4e6ba188f5bef2330333144897af4c0573eab09a1;

        skip(10 days);

        vm.prank(CHARLIE);
        vm.expectRevert(SafeYieldAirdrop.SYA__INVALID_PROOF.selector);
        airdrop.stakeAndVestSayTokens(1_000e18, aliceMerkleProof);
    }

    function testStakeAndVest() public {
        //end presale
        vm.startPrank(protocolAdmin);
        presale.endPresale();
        vm.stopPrank();

        vm.prank(protocolAdmin);
        presale.transferRemainingSayToken(address(airdrop));

        bytes32[] memory aliceMerkleProof = new bytes32[](2);
        aliceMerkleProof[0] = 0x2eaff8d51273cf94a9fc990c007506ea709ab23f02d96f0516a28485c0a9f939;
        aliceMerkleProof[1] = 0x4f01082713464f7c40bfbee4e6ba188f5bef2330333144897af4c0573eab09a1;

        vm.prank(ALICE);
        airdrop.stakeAndVestSayTokens(1_000e18, aliceMerkleProof);

        vm.prank(protocolAdmin);
        configs.setVestingStartTime(uint48(block.timestamp));

        /**
         * alice claims after 1.5 month
         */
        skip(45 * 24 * 60 * 60 seconds);

        uint256 aliceFirstMonthCalculated = (2_000 * 1_000e18) / 10_000;
        uint256 aliceSecondMonthCalculated = (1_000 * 1_000e18) / 10_000;

        vm.startPrank(ALICE);
        staking.unstakeVestedTokens();
        vm.stopPrank();
        /**
         * First month:
         * Alice : 20% * 1_000e18  = 200e18
         * Second month:
         * Alice : 10% * 1_000e18  = 100e18
         * total safe tokens = 200e18 + 100e18 = 300e18
         */
        assertEq(safeToken.balanceOf(ALICE), aliceFirstMonthCalculated + aliceSecondMonthCalculated);
    }
}
