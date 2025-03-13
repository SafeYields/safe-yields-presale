// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { SafeYieldAirdrop } from "src/SafeYieldAirdrop.sol";
import { SafeYieldBaseTest } from "./setup/SafeYieldBaseTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Test, console } from "forge-std/Test.sol";

contract SafeYieldAirdropTest is SafeYieldBaseTest {
    function testShouldFailIfInvalidMerkleIsSet() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(SafeYieldAirdrop.SYA__INVALID_MERKLE_ROOT.selector);
        airdrop.setMerkleRoot(bytes32(0));
    }

    function testShouldFailIfClawBackAmountIsZero() public {
        vm.startPrank(protocolAdmin);

        vm.expectRevert(SafeYieldAirdrop.SYA__INVALID_AMOUNT.selector);
        airdrop.clawBackSayTokens(0);
    }

    function testClawBackSayTokens() public {
        vm.startPrank(protocolAdmin);
        presale.endPresale();
        vm.stopPrank();

        vm.prank(protocolAdmin);
        presale.transferRemainingSayToken(address(airdrop));

        uint256 sayTokenAirdropBalance = safeToken.balanceOf(address(airdrop));

        uint256 protocolSayBalancePrior = safeToken.balanceOf(address(protocolAdmin));

        vm.startPrank(protocolAdmin);
        airdrop.clawBackSayTokens(sayTokenAirdropBalance);

        assertEq(safeToken.balanceOf(address(protocolAdmin)), protocolSayBalancePrior + sayTokenAirdropBalance);
    }

    function testSetNewConfig() public {
        vm.startPrank(protocolAdmin);

        airdrop.setConfig(makeAddr("NewConfig"));

        assertEq(address(airdrop.safeYieldConfigs()), makeAddr("NewConfig"));
    }

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

        address USER = 0x7CdB4B62b8a06a1D2e368FAFA3A082aafd9651BF;

        vm.prank(protocolAdmin);
        presale.transferRemainingSayToken(address(airdrop));

        bytes32[] memory userMerkleProof = new bytes32[](8);
        userMerkleProof[0] = 0x7bf07078d6dd6e5f6cb26feff0d2f7f3a038c36d3f4b91d305df5f64f7272661;
        userMerkleProof[1] = 0x5df445492b30a45dcfb7fd592cb082e8242677688684292bbea544d569aff4d6;
        userMerkleProof[2] = 0x34eb03847ad7c4c9cc2d2a148a11d5669ea453ecb0d78298878bb982b50240dc;
        userMerkleProof[3] = 0xc28bb53e1f19b38f4683fa272c99e90be7b1c27e6b4411cc5bad76f48d8639d5;
        userMerkleProof[4] = 0x6be9f333f82207efd07219d1a22977e8d665e77724bde257efb2c9a19fac12dd;
        userMerkleProof[5] = 0x29e1583389c64d38e2421bc28f1c60fa1ec7e5ac27c542a0e3e3454540ebbf86;
        userMerkleProof[6] = 0xa1bc53493dd440e4f66bf25f689093a86007d4222c8b97852d8ab6026ff6e992;
        userMerkleProof[7] = 0x0f9afc0df784ce3410a0cb63deec675a9ba2dcdf0b10595ac1c9dda9c8e2b799;

        skip(5 minutes);

        vm.prank(USER);
        airdrop.stakeAndVestSayTokens(10_000e18, userMerkleProof);

        skip(5 days);

        vm.prank(USER);
        vm.expectRevert(SafeYieldAirdrop.SYA__TOKENS_CLAIMED.selector);
        airdrop.stakeAndVestSayTokens(10_000e18, userMerkleProof);
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

        address USER = 0x7CdB4B62b8a06a1D2e368FAFA3A082aafd9651BF;

        bytes32[] memory userMerkleProof = new bytes32[](8);
        userMerkleProof[0] = 0x7c4b578bfb8602a12ec6503949c6ed8a57b3d9e2b3876e460997a808b3a55a5c;
        userMerkleProof[1] = 0x52c3264235c87bb7d47ac40c912ffc3c26fcb2c6e3cf7ba33540204fd845ae78;
        userMerkleProof[2] = 0xcabd9dc20d87a692718e3f393779f46edf4886893b88361431b9a8ccae112d85;
        userMerkleProof[3] = 0x3140727669021e58a02b874b7b4567a40e32b061e6ee3c19fc4ef9fe2164686e;
        userMerkleProof[4] = 0x6c8483dd175539a3be94e41012e004742098763ffa0e54b3fd52745a570197dc;
        userMerkleProof[5] = 0xf0e34f3d06c2b99e110014022d4445e9de90081cdcd3bea92cbe4edfef4a2092;
        userMerkleProof[6] = 0xb6063910d6ac13104f2acd8e7e407d552d9031a1f4c479df9909fe9363bd85b7;
        userMerkleProof[7] = 0x5bed3324fa7692a4241d02b43eac9aa5734cdd46d310f68d5cdeda21ff050091;

        vm.prank(USER);
        airdrop.stakeAndVestSayTokens(10_000e18, userMerkleProof);

        vm.prank(protocolAdmin);
        configs.setIDO(makeAddr("SafeYieldLP"));

        /**
         * alice claims after 1.5 month
         * cliff is 1 month
         * alice can start vesting after the first month
         */
        skip(45 * 24 * 60 * 60 seconds);

        uint256 aliceFirsMonthCalculated = (1_000 * 10_000e18) / 10_000;

        vm.startPrank(USER);

        safeYieldVesting.unlock_sSayTokens();

        console.log("Staked Say balance", IERC20(staking).balanceOf(USER));

        staking.unStake(uint128(IERC20(staking).balanceOf(USER)));
        vm.stopPrank();
        /**
         * First month:
         * Alice : 10% * 10_000e18  = 1_000e18
         */
        assertEq(safeToken.balanceOf(USER), aliceFirsMonthCalculated);
    }
}
