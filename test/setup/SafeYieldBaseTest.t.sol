// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMockToken } from "../mocks/SafeMockToken.sol";
import { SafeToken } from "src/SafeToken.sol";
import { USDCMockToken } from "../mocks/USDCMockToken.sol";
import { RewardMockToken } from "../mocks/RewardMockToken.sol";
import { SafeYieldRewardDistributorMock } from "../mocks/SafeYieldRewardDistributorMock.sol";
import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
import { SafeYieldCoreContributorsVesting } from "src/SafeYieldCoreContributorsVesting.sol";
import { SafeYieldTokenDistributor } from "src/SafeYieldTokenDistributor.sol";
import { SafeYieldVesting } from "src/SafeYieldVesting.sol";
import { SafeYieldConfigs } from "src/SafeYieldConfigs.sol";
import { SafeYieldAirdrop } from "src/SafeYieldAirdrop.sol";
import { SafeYieldTWAP } from "src/SafeYieldTWAP.sol";
import { IUniswapV3Factory } from "src/uniswapV3/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "src/uniswapV3/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "src/uniswapV3/interfaces/ISwapRouter.sol";
import { INonFungiblePositionManager } from "src/uniswapV3/interfaces/INonFungiblePositionManager.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract SafeYieldBaseTest is Test {
    uint256 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint256 public constant STAKING_MAX_SUPPLY = 11_000_000e18;
    uint128 public constant CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT = 1_000_000e18;
    address public constant UNISWAP_V3_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    ISwapRouter public swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonFungiblePositionManager public nonFungiblePositionManager =
        INonFungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    SafeYieldTokenDistributor public tokensDistributor;

    address public teamOperations = makeAddr("teamOperations");
    address public usdcBuyback = makeAddr("usdcBuyback");
    address public protocolAdmin = makeAddr("protocolAdmin");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public CHARLIE = makeAddr("charlie");
    address public NOT_ADMIN = makeAddr("notAdmin");
    address public NOT_MINTER = makeAddr("notMinter");
    address public USDC_WHALE = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;
    bytes32 public merkleRoot = 0xcd59351353200fd0a3c810bb8c2042aed3ffe2cdbfc1f6c86a2adaf938b2bf4d;

    SafeYieldRewardDistributorMock public distributor;
    SafeYieldVesting public safeYieldVesting;
    SafeYieldCoreContributorsVesting public contributorVesting;
    SafeYieldConfigs public configs;
    SafeYieldPresale public presale;
    SafeYieldStaking public staking;
    SafeYieldAirdrop public airdrop;
    SafeYieldTWAP public twap;
    SafeToken public safeToken;
    USDCMockToken public usdc;
    RewardMockToken rewardToken;

    uint256 public arbitrumFork;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    error EnforcedPause();

    modifier startPresale() {
        vm.startPrank(protocolAdmin);
        presale.startPresale();
        vm.stopPrank();
        _;
    }

    modifier startEndPresale() {
        vm.startPrank(protocolAdmin);
        presale.endPresale();
        vm.stopPrank();
        _;
    }

    function setUp() public virtual {
        vm.startPrank(protocolAdmin);

        usdc = new USDCMockToken("USDC", "USDC", 6);

        rewardToken = new RewardMockToken("RewardToken", "RT", 6);

        safeToken = new SafeToken();

        configs = new SafeYieldConfigs(protocolAdmin);

        staking = new SafeYieldStaking(address(safeToken), address(usdc), address(configs));

        tokensDistributor = new SafeYieldTokenDistributor(protocolAdmin, address(configs));

        twap = new SafeYieldTWAP();

        presale = new SafeYieldPresale(
            address(safeToken),
            address(usdc),
            address(configs),
            1_000e18,
            uint128(PRE_SALE_MAX_SUPPLY),
            0.8e17,
            500,
            500,
            protocolAdmin
        );
        //12_500 00 00 00 00 00 00 00 00 00

        safeYieldVesting = new SafeYieldVesting(protocolAdmin, address(staking), address(configs));

        distributor = new SafeYieldRewardDistributorMock(
            address(safeToken), address(usdc), teamOperations, usdcBuyback, address(staking), address(twap)
        );

        airdrop = new SafeYieldAirdrop(address(safeToken), address(configs), protocolAdmin);

        contributorVesting = new SafeYieldCoreContributorsVesting(protocolAdmin, address(safeToken));

        safeToken.setAllocationLimit(address(distributor), STAKING_MAX_SUPPLY);
        safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);
        safeToken.setAllocationLimit(address(contributorVesting), CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT);

        staking.addCallback(address(tokensDistributor));

        staking.approveStakingAgent(address(presale), true);
        staking.approveStakingAgent(protocolAdmin, true);
        staking.approveStakingAgent(address(airdrop), true);
        staking.approveStakingAgent(address(safeYieldVesting), true);

        configs.setPresale(address(presale));
        configs.updateSafeStaking(address(staking));
        configs.setRewardDistributor(address(distributor));
        configs.setSafeYieldVesting(address(safeYieldVesting));

        contributorVesting.mintSayAllocation(CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT);
        presale.mintPreSaleAllocation(PRE_SALE_MAX_SUPPLY);
        distributor.mintStakingEmissionAllocation(STAKING_MAX_SUPPLY);

        safeYieldVesting.approveVestingAgent(address(staking), true);
        safeYieldVesting.approveVestingAgent(protocolAdmin, true);

        airdrop.setMerkleRoot(merkleRoot);

        vm.stopPrank();

        //address uniswapV3Pool = _createUniswapV3Pool();

        vm.prank(protocolAdmin);
        distributor.updateSafePool(address(0));

        _mintUsdc2Users();

        rewardToken.mint(protocolAdmin, 10_000e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    function _mintUsdc2Users() internal {
        usdc.mint(ALICE, 2_001_000e6);
        usdc.mint(BOB, 2_001_000e6);
        usdc.mint(CHARLIE, 2_001_000e6);
    }

    function _createUniswapV3Pool() internal returns (address pool) {
        // uint160 initialPrice = 1e18;

        // uint256 sqrtPrice = Math.sqrt(initialPrice);

        // uint256 QX96 = 2 ** 96;

        // uint160 sqrtPriceX96_ = uint160(sqrtPrice * QX96);

        // pool =
        //     nonFungiblePositionManager.createAndInitializePoolIfNecessary(address(safeToken), USDC, 500, sqrtPriceX96_);
        // (
        //     uint160 sqrtPriceX96,
        //     int24 tick,
        //     uint16 observationIndex,
        //     uint16 observationCardinality,
        //     uint16 observationCardinalityNext,
        //     uint8 feeProtocol,
        //     bool unlocked
        // ) = IUniswapV3Pool(pool).slot0();

        // console.log("Tick", uint256(int256(tick)));

        // INonFungiblePositionManager.MintParams memory mintParams = INonFungiblePositionManager.MintParams({
        //     token0: address(safeToken),
        //     token1: USDC,
        //     fee: 500,
        //     tickLower: 0 - IUniswapV3Pool(pool).tickSpacing() * 10,
        //     tickUpper: 0 + IUniswapV3Pool(pool).tickSpacing() * 10,
        //     amount0Desired: 5_000e18,
        //     amount1Desired: 10_000e6,
        //     amount0Min: 0,
        //     amount1Min: 0,
        //     recipient: USDC_WHALE,
        //     deadline: block.timestamp + 100
        // });

        // _transferSafeTokens(USDC_WHALE, 10_000e18);

        // vm.startPrank(USDC_WHALE);

        // console.log("usdc balance of WHALE", IERC20(USDC).balanceOf(USDC_WHALE));

        // //approve tokens
        // safeToken.approve(address(nonFungiblePositionManager), 5_000e18);
        // IERC20(USDC).approve(address(nonFungiblePositionManager), 10_000e6);

        // (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
        //     nonFungiblePositionManager.mint(mintParams);

        // console.log("tokenId", tokenId);
        // console.log("liquidity", liquidity);
        // console.log("amount0", amount0);
        // console.log("amount1", amount1);

        // vm.stopPrank();
    }

    function _transferSafeTokens(address user, uint128 amount) internal {
        vm.startPrank(address(distributor));
        safeToken.transfer(user, amount);
        vm.stopPrank();
    }
}
