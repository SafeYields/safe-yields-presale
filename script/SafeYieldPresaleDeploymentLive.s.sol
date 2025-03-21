// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

// import { Script, console } from "forge-std/Script.sol";
// import { SafeYieldPresale } from "src/SafeYieldPresale.sol";
// import { SafeYieldStaking } from "src/SafeYieldStaking.sol";
// import { SafeToken } from "src/SafeToken.sol";
// import { SafeYieldTWAP } from "src/SafeYieldTWAP.sol";
// import { SafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";

// contract SafeYieldPresaleDeployment is Script {
//     uint128 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
//     uint128 public constant STAKING_MAX_SUPPLY = 11_000_000e18;

//     address public constant SAFE_YIELD_DEPLOYER = 0x3e88e60894D081B27D180fcADd524365A3DE7Dd4;

//     address public constant SY_ADMIN = 0x0378da1e9D6bB039e2E06EDAf43e8744ea204244;
//     address public constant TEAM_OPERATIONS = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;
//     address public constant USDC_BUY_BACK = TEAM_OPERATIONS;
//     address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
//     address public constant PROTOCOL_MULTISIG = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;

//     SafeYieldPresale public presale;
//     SafeYieldStaking public staking;
//     SafeYieldRewardDistributor public distributor;
//     SafeToken public safeToken;
//     SafeYieldTWAP twap;

//     uint128 minAllocationPerWallet = 1e18;
//     uint128 maxAllocationPerWallet = PRE_SALE_MAX_SUPPLY;
//     uint128 tokenPrice = 8e17; //e.g 0.8 usdc
//     uint128 referrerCommissionUsdcBps = 500; //5% => 500 bps
//     uint128 referrerCommissionSafeTokenBps = 500; // 5% => 500 bps

//     /**
//      * @dev Run the script to deploy contracts to Arbitrum One
//      * @dev replace "ARBITRUM_SCAN_API_KEY" with your arbiscan api key
//      * forge script script/SafeYieldPresaleDeploymentLive.s.sol --rpc-url https://rpc.ankr.com/arbitrum	 --etherscan-api-key "ARBITRUM_SCAN_API_KEY" --verify --vv
//      */
//     function run() public {
//         uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
//         vm.startBroadcast(deployerPrivateKey);

//         safeToken = new SafeToken(); //deploy new safe token

//         staking = new SafeYieldStaking(address(safeToken), USDC); // deploy new staking contract

//         presale = new SafeYieldPresale(
//             address(safeToken),
//             USDC,
//             address(staking),
//             minAllocationPerWallet,
//             maxAllocationPerWallet,
//             tokenPrice,
//             referrerCommissionUsdcBps,
//             referrerCommissionSafeTokenBps,
//             PROTOCOL_MULTISIG
//         );

//         twap = new SafeYieldTWAP();

//         distributor = new SafeYieldRewardDistributor(
//             address(safeToken), USDC, TEAM_OPERATIONS, USDC_BUY_BACK, address(staking), address(twap)
//         );

//         //set allocation limits
//         safeToken.setAllocationLimit(address(distributor), STAKING_MAX_SUPPLY);
//         safeToken.setAllocationLimit(address(presale), PRE_SALE_MAX_SUPPLY);

//         staking.setPresale(address(presale));
//         staking.setRewardDistributor(address(distributor));

//         //mint allocations
//         presale.mintPreSaleAllocation();
//         distributor.mintStakingEmissionAllocation();

//         vm.stopBroadcast();

//         _validateConfigs();

//         _logAddresses();
//     }

//     function _logAddresses() internal view {
//         console.log("USDC", USDC);
//         console.log("Safe Token", address(safeToken));
//         console.log("Staking", address(staking));
//         console.log("Presale", address(presale));
//         console.log("TWAP", address(twap));
//         console.log("Distributor", address(distributor));
//     }

//     function _validateConfigs() internal view {
//         //validate presale configuration
//         require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
//         require(address(presale.safeYieldStaking()) == address(staking), "Invalid staking address");
//         require(address(presale.safeToken()) == address(safeToken), "Invalid safeToken token address");
//         require(address(presale.usdcToken()) == USDC, "Invalid usdc address");
//         require(presale.minAllocationPerWallet() == minAllocationPerWallet, "Invalid min allocation per wallet");
//         require(presale.maxAllocationPerWallet() == maxAllocationPerWallet, "Invalid max allocation per wallet");
//         require(
//             presale.referrerCommissionSafeTokenBps() == referrerCommissionSafeTokenBps,
//             "Invalid referrer commission safeToken token bps"
//         );
//         require(
//             presale.referrerCommissionUsdcBps() == referrerCommissionUsdcBps, "Invalid referrer commission usdc bps"
//         );

//         //validate staking configuration
//         require(address(staking.safeToken()) == address(safeToken), "Invalid safeToken token address");
//         require(address(staking.usdc()) == USDC, "Invalid usdc address");
//         require(address(staking.distributor()) == address(distributor), "Invalid distributor address");
//         require(address(staking.safeYieldPresale()) == address(presale), "Invalid presale address");

//         //validate distributor configuration
//         require(safeToken.balanceOf(address(presale)) == PRE_SALE_MAX_SUPPLY, "Invalid presale allocation");
//         require(address(distributor.safeToken()) == address(safeToken), "Invalid safeToken token address");
//         require(address(distributor.usdcToken()) == USDC, "Invalid usdc address");
//         require(address(distributor.safeYieldTWAP()) == address(twap), "Invalid twap address");
//         require(distributor.teamOperations() == TEAM_OPERATIONS, "Invalid team operations address");
//         require(distributor.usdcBuyback() == USDC_BUY_BACK, "Invalid usdc buyback address");
//         require(distributor.safeStaking() == address(staking), "Invalid staking address");
//     }
// }
