// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale, ISafeYieldPreSale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking, ISafeYieldStaking, Stake } from "src/SafeYieldStaking.sol";
import { SafeYieldLockUp } from "src/SafeYieldLockUp.sol";
import { SafeYieldRewardDistributor, ISafeYieldRewardDistributor } from "src/SafeYieldRewardDistributor.sol";
import { SafeYieldTokenDistributor } from "src/SafeYieldTokenDistributor.sol";
import { SafeYieldAirdrop } from "src/SafeYieldAirdrop.sol";
import { SafeYieldCoreContributorsLockUp } from "src/SafeYieldCoreContributorsLockUp.sol";
import { SafeToken, ISafeToken } from "src/SafeToken.sol";
import { SafeYieldConfigs } from "src/SafeYieldConfigs.sol";

contract SafeYieldPresaleDeploymentPath5 is Script {
    address public constant OLD_STAKING = 0xBF220A4C1Ae2367508de12E84BbadfFF6D5698E0;
    address public constant OLD_PRESALE = 0x2Ef0b6e2cE395662ECF6a0E33CC4D7e51D92F238;
    address public constant OLD_REWARD_DISTRIBUTOR = 0xe6323ce95eA3F026E46215b404EAd05f381B3fC7;
    address public constant SAY_TOKEN = 0x19D4b337B77b04256668679159E0b78A42fb0a1a;
    address public constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant SY_ADMIN = 0x3e88e60894D081B27D180fcADd524365A3DE7Dd4;
    address public constant PROTOCOL_MULTISIG = 0xb7eCbD7262a9250A44EaA040A2B2a184536F3861;
    bytes32 public constant MERKLE_ROOT = 0x09d4267a42b2b82ffc3599f877a3305637af8394f4d19ffb1fafdc9ab482c47b; //!change merkle root
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint128 public constant PRE_SALE_MAX_SUPPLY = 2_000_000e18;
    uint128 public constant STAKING_MAX_SUPPLY = 11_000_000e18;
    uint128 public constant CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT = 1_000_000e18;
    uint128 public constant minAllocationPerWallet = 1e18;
    uint128 public constant maxAllocationPerWallet = PRE_SALE_MAX_SUPPLY;
    uint128 public constant tokenPrice = 8e17; //e.g 0.8 usdc
    uint128 public constant referrerCommissionUsdcBps = 500; //5% => 500 bps
    uint128 public constant referrerCommissionSafeTokenBps = 500; // 5% => 500 bps

    SafeToken public sayToken = SafeToken(SAY_TOKEN);
    ISafeYieldStaking public oldStaking = ISafeYieldStaking(OLD_STAKING);
    ISafeYieldPreSale public oldPresale = ISafeYieldPreSale(OLD_PRESALE);
    ISafeYieldRewardDistributor public oldDistributor = ISafeYieldRewardDistributor(OLD_REWARD_DISTRIBUTOR);

    SafeYieldStaking public syStaking;
    SafeYieldConfigs public syConfig;
    SafeYieldLockUp public syLockUp;
    SafeYieldPresale public syPresale;
    SafeYieldTokenDistributor public syTokenDistributor;
    SafeYieldAirdrop public syAirdrop;
    SafeYieldCoreContributorsLockUp public syCoreContributorsLockUp;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK_DL");
        vm.startBroadcast(deployerPrivateKey);
        //vm.startPrank(SY_ADMIN);

        uint256 oldStakingSAYBalance = sayToken.balanceOf(OLD_STAKING);
        uint256 oldPreSaleSAYBalance = sayToken.balanceOf(OLD_PRESALE);

        //pause the old contracts
        oldPresale.pause();
        oldStaking.pause();

        sayToken.grantRole(BURNER_ROLE, SY_ADMIN);

        //burn the say tokens
        sayToken.burn(OLD_STAKING, oldStakingSAYBalance);
        sayToken.burn(OLD_PRESALE, oldPreSaleSAYBalance);

        sayToken.setAllocationLimit(SY_ADMIN, oldStakingSAYBalance);

        syConfig = new SafeYieldConfigs(SY_ADMIN);

        syCoreContributorsLockUp = new SafeYieldCoreContributorsLockUp(SY_ADMIN, SAY_TOKEN);

        syPresale = new SafeYieldPresale(
            SAY_TOKEN,
            USDC_ARB,
            address(syConfig),
            minAllocationPerWallet,
            maxAllocationPerWallet,
            tokenPrice,
            referrerCommissionUsdcBps,
            referrerCommissionSafeTokenBps,
            PROTOCOL_MULTISIG
        );

        syStaking = new SafeYieldStaking(SAY_TOKEN, USDC_ARB, address(syConfig));

        syLockUp = new SafeYieldLockUp(SY_ADMIN, address(syStaking), address(syConfig));

        syAirdrop = new SafeYieldAirdrop(SAY_TOKEN, address(syConfig), SY_ADMIN);

        syTokenDistributor = new SafeYieldTokenDistributor(SY_ADMIN, address(syConfig));

        //set configs
        syConfig.setPresale(address(syPresale));
        syConfig.updateSafeStaking(address(syStaking));
        syConfig.setRewardDistributor(address(OLD_REWARD_DISTRIBUTOR));
        syConfig.setLockUp(address(syLockUp));

        /**
         * To account for tokens minted during the previous presale, we subtract them from the main allocation.
         * The admin can then mint the `oldStakingSAYBalance` to stake on behalf of users.
         */
        uint256 sayAmountRemainingForPresale = PRE_SALE_MAX_SUPPLY - oldStakingSAYBalance;

        //set say token allocations
        sayToken.setAllocationLimit(address(syPresale), sayAmountRemainingForPresale);

        sayToken.setAllocationLimit(address(syCoreContributorsLockUp), CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT);
        //set staking configs
        syStaking.addCallback(address(syTokenDistributor));

        syStaking.approveStakingAgent(address(syPresale), true);
        syStaking.approveStakingAgent(SY_ADMIN, true);
        syStaking.approveStakingAgent(address(syAirdrop), true);
        syStaking.approveStakingAgent(address(syLockUp), true);

        //mint allocations
        syCoreContributorsLockUp.mintSayAllocation(CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT);
        syPresale.mintPreSaleAllocation(sayAmountRemainingForPresale);

        //approve lock up vesting agents
        syLockUp.approveVestingAgent(address(syStaking), true);
        syLockUp.approveVestingAgent(SY_ADMIN, true);

        //validate contracts
        _validateConfigs(sayAmountRemainingForPresale);

        //log address
        _logAddresses();

        vm.stopBroadcast();
        //vm.stopPrank();
    }

    function _logAddresses() internal view {
        console.log("Staking", address(syStaking));
        console.log("Presale", address(syPresale));
        console.log("Configs", address(syConfig));
        console.log("LockUp", address(syLockUp));
        console.log("CoreContributorsLockUp", address(syCoreContributorsLockUp));
        console.log("TokenYieldDistributor", address(syTokenDistributor));
        console.log("Airdrop", address(syAirdrop));
        console.log("");
    }

    function _validateConfigs(uint256 presaleSayAmount) internal view {
        //validate presale configuration
        require(sayToken.balanceOf(address(syPresale)) == presaleSayAmount, "Invalid presale allocation");
        require(address(syPresale.safeToken()) == address(sayToken), "Invalid sayToken token address");
        require(address(syPresale.usdcToken()) == USDC_ARB, "Invalid usdc address");
        require(address(syPresale.safeYieldConfigs()) == address(syConfig), "Invalid config address");

        require(syPresale.minAllocationPerWallet() == minAllocationPerWallet, "Invalid min allocation per wallet");
        require(syPresale.maxAllocationPerWallet() == maxAllocationPerWallet, "Invalid max allocation per wallet");
        require(
            syPresale.referrerCommissionSafeTokenBps() == referrerCommissionSafeTokenBps,
            "Invalid referrer commission say token bps"
        );
        require(
            syPresale.referrerCommissionUsdcBps() == referrerCommissionUsdcBps, "Invalid referrer commission usdc bps"
        );

        //validate staking configuration
        require(address(syStaking.safeToken()) == address(sayToken), "Invalid safeToken token address");
        require(address(syStaking.usdc()) == USDC_ARB, "Invalid usdc address");
        require(address(syStaking.safeYieldConfigs()) == address(syConfig), "Invalid config address");
        require(syStaking.getAllCallbacks().length == 1, "Invalid number of callbacks");
        require(address(syStaking.getCallback(0)) == address(syTokenDistributor), "Invalid callback");

        //validate lockup configurations
        require(address(syLockUp.safeYieldConfigs()) == address(syConfig), "Invalid config address");
        require(address(syLockUp.sSayToken()) == address(syStaking), "Invalid sSafeToken token address");
        require(syLockUp.approvedVestingAgents(address(syStaking)) == true, "Staking contract not approved");
        require(syLockUp.approvedVestingAgents(SY_ADMIN) == true, "Admin not approved");

        //validate airdrop
        require(address(syAirdrop.sayToken()) == address(sayToken), "Invalid safeToken token address");
        require(address(syAirdrop.safeYieldConfigs()) == address(syConfig), "Invalid config address");

        //validate core contributors
        require(address(syCoreContributorsLockUp.sayToken()) == address(sayToken), "Invalid safeToken token address");
        require(
            sayToken.balanceOf(address(syCoreContributorsLockUp)) == CORE_CONTRIBUTORS_TOTAL_SAY_AMOUNT,
            "Invalid core contributors lockup allocation"
        );

        //configs
        require(address(syConfig.safeYieldPresale()) == address(syPresale), "Invalid presale address");
        require(address(syConfig.safeYieldDistributor()) == address(oldDistributor), "Invalid reward distributor");
        require(address(syConfig.safeYieldLockUp()) == address(syLockUp), "Invalid presale address");
        require(address(syConfig.safeYieldStaking()) == address(syStaking), "Invalid presale address");

        // token distributor
        require(address(syTokenDistributor.safeYieldConfigs()) == address(syConfig), "Invalid config address");
    }
}
