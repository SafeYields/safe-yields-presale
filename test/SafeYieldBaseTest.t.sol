// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMockToken } from "./mocks/SafeMockToken.sol";
import { SafeToken } from "src/SafeToken.sol";
import { sSafeToken } from "src/sSafeToken.sol";
import { USDCMockToken } from "./mocks/USDCMockToken.sol";
import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";

abstract contract SafeYieldBaseTest is Test {
    uint256 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint256 public constant STAKING_MAX_SUPPLY = 11_000_000e18;

    address public teamOperations = makeAddr("teamOperations");
    address public usdcBuyback = makeAddr("usdcBuyback");
    address public protocolAdmin = makeAddr("protocolAdmin");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public NOT_ADMIN = makeAddr("notAdmin");
    address public NOT_MINTER = makeAddr("notMinter");

    SafeYieldRewardDistributor public distributor;
    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeToken public safeToken;
    USDCMockToken public usdc;
    sSafeToken public sToken;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    error EnforcedPause();

    function setUp() public {
        vm.startPrank(protocolAdmin);
        usdc = new USDCMockToken("USDC", "USDC", 6);
        safeToken = new SafeToken("SafeToken", "SAFE", protocolAdmin);
        sToken = new sSafeToken("sSafeToken", "sSAFE", protocolAdmin);

        staking = new SafeYieldStaking(address(safeToken), address(sToken), address(usdc), protocolAdmin);

        presale = new SafeYieldPresale(
            address(safeToken),
            address(sToken),
            address(usdc),
            address(staking),
            1_000e18,
            100_000e18,
            1e18,
            5_00,
            5_00,
            protocolAdmin
        );

        distributor = new SafeYieldRewardDistributor(
            address(safeToken), address(usdc), teamOperations, usdcBuyback, address(staking), protocolAdmin
        );

        safeToken.setAllocationLimit(address(distributor), STAKING_MAX_SUPPLY);
        safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        staking.setPresale(address(presale));

        sToken.grantRole(sToken.MINTER_ROLE(), address(staking));
        sToken.grantRole(sToken.BURNER_ROLE(), address(staking));

        //mint
        presale.mintAllAllocations();

        distributor.mintAllAllocations();

        _mintUsdc2Users();

        vm.stopPrank();
    }

    function _mintUsdc2Users() internal {
        usdc.mint(ALICE, 110_000e6);
        usdc.mint(BOB, 110_000e6);
    }
}
