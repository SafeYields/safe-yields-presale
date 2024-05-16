// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMockToken} from "./mocks/SafeMockToken.sol";
import {USDCMockToken} from "./mocks/USDCMockToken.sol";
import {SafeYieldRewardDistributor} from "src/SafeYieldRewardDistributor.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {SafeYieldStaking} from "src/SafeYieldStaking.sol";

abstract contract SafeYieldBaseTest is Test {
    uint256 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint256 public constant STAKING_MAX_SUPPLY = 11_000_000e18;

    address public teamOperations = makeAddr("teamOperations");
    address public usdcBuyback = makeAddr("usdcBuyback");
    address public protocolAdmin = makeAddr("protocolAdmin");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");

    SafeYieldRewardDistributor public distributor;
    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeMockToken public safeToken;
    USDCMockToken public usdc;
    USDCMockToken public sSafeToken;

    function setUp() public {
        vm.startPrank(protocolAdmin);
        usdc = new USDCMockToken("USDC", "USDC", 6);
        safeToken = new SafeMockToken("SafeToken", "SAFE", 18);
        sSafeToken = new USDCMockToken("sSafeToken", "sSAFE", 18);

        staking = new SafeYieldStaking(
            address(safeToken),
            address(sSafeToken),
            address(usdc),
            protocolAdmin
        );

        presale = new SafeYieldPresale(
            address(safeToken),
            address(usdc),
            address(staking),
            uint128(PRE_SALE_MAX_SUPPLY),
            1000e18,
            100_000e18,
            1e18,
            5_00,
            5_00
        );

        distributor = new SafeYieldRewardDistributor(
            address(safeToken),
            address(usdc),
            teamOperations,
            usdcBuyback,
            address(staking),
            protocolAdmin
        );

        safeToken.grantRole(safeToken.MINTER_ROLE(), address(distributor));
        safeToken.grantRole(safeToken.MINTER_ROLE(), address(presale));

        safeToken.setMinterLimit(address(distributor), STAKING_MAX_SUPPLY);
        safeToken.setMinterLimit(address(presale), PRE_SALE_MAX_SUPPLY);

        _mintUsdc2Users();

        vm.stopPrank();
    }

    function _mintUsdc2Users() internal {
        usdc.mint(ALICE, 110_000e6);
        usdc.mint(BOB, 100_000e6);
    }
}
