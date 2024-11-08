// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;
//todo:
/**
 *  1. retrieve SAY tokens from old Staking contract
 *  2. burn the say
 *  2. get array of address, get their staked SAY.
 *  3. stake for users in the new staking.
 */
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

contract SafeYieldPresaleDeploymentMigrate is Script {
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
        //vm.startBroadcast(deployerPrivateKey);//!use when deploying to mainnet
        vm.startPrank(SY_ADMIN);

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

        syAirdrop = new SafeYieldAirdrop(SAY_TOKEN, address(syConfig), MERKLE_ROOT, SY_ADMIN);

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

        //admin to mint say to stake for users
        sayToken.mint(oldStakingSAYBalance);

        //stake for OldStaking users
        _stakeForMultipleUsers(oldStakingSAYBalance);

        //assertions
        _assertMultipleUserStakeForNewStaking();

        //vm.stopBroadcast();
        vm.stopPrank();
    }

    function _stakeForMultipleUsers(uint256 totalStakedSay) internal {
        address[] memory userAddresses = getOldStakingUserAddresses();

        //approve total amounts to stake
        sayToken.approve(address(syStaking), totalStakedSay);

        uint256 numOfUsers = userAddresses.length;

        for (uint256 i = 0; i < numOfUsers; i++) {
            //stake for them
            syStaking.stakeFor(userAddresses[i], oldStaking.getUserStake(userAddresses[i]).stakeAmount, true);
        }
    }

    function _assertMultipleUserStakeForNewStaking() internal view {
        address[] memory userAddresses = getOldStakingUserAddresses();

        uint256 numOfUsers = userAddresses.length;

        for (uint256 i = 0; i < numOfUsers; i++) {
            //assert new stake amounts
            require(syStaking.getUserStake(userAddresses[i]).stakeAmount > 0, "Invalid user stake amount");
        }
    }

    function getOldStakingUserAddresses() internal pure returns (address[] memory userAddresses) {
        userAddresses = new address[](33);

        userAddresses[0] = 0x3BD358b35b6Ff3cADf01Ac118b3d21Ee62E56C0C;
        userAddresses[1] = 0xEeE9Ef09B9D9dE0B8aA47A781bA7aCF87818C05f;
        userAddresses[2] = 0x6405f47Be0D616E7f59749cdAF8e8b180CaA18cB;
        userAddresses[3] = 0x12f6471bF62193467e0985CAD1747d077dfc0723;
        userAddresses[4] = 0xFb2afe0bA538f839D093197C1c324AB3Bc73d53f;
        userAddresses[5] = 0x46BA2EbDE072bEa26fA4b54eEc6b6C39b5FEc10e;
        userAddresses[6] = 0xc3D5CdC556Bf7A012039194a5575486c212164a9;
        userAddresses[7] = 0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF;
        userAddresses[8] = 0x3Dac0bDdfa0F9b3d86031A0bfbf7804030AB83b2;
        userAddresses[9] = 0xa9E94416Aa43913c8E779Cf356bC0C6a250EA6Bf;
        userAddresses[10] = 0x6501B7A416ed4d861129A4B2EFa90B364d4E776C;
        userAddresses[11] = 0x3e03B0593E125666Ba4B7479186b20FbD4146dF3;
        userAddresses[12] = 0xD42cf8d4f72a6b26e13EFe43A198aaF05CB835ae;
        userAddresses[13] = 0xfb59b257aF5518787E32D8DD1a8cf0DE13393385;
        userAddresses[14] = 0x3f6A905FF080c3e0A6307af4CFe9842ad87EBCeB;
        userAddresses[15] = 0x8B376f5e02090499c2c4fBd900E1bC18EF4961d4;
        userAddresses[16] = 0xD4d3E342902766344075D06c94391e61A9bB7e60;
        userAddresses[17] = 0x03Cbd99F5A7c39c7499273AbB8363b0372cc7930;
        userAddresses[18] = 0x35434690bd439c8936e94B148246AE208Dfc9851;
        userAddresses[19] = 0x28f0ee52A63d57f494D7968DBcf66156AfAEf3de;
        userAddresses[20] = 0xA32851095944385b930713885f2af518e0b7e45C;
        userAddresses[21] = 0xaf5Ae7CdAff6f1f457bc88F0989c0AF7f583Ab43;
        userAddresses[22] = 0xFaf790Ff539471763Da851d63AD1A47D0F95f2A6;
        userAddresses[23] = 0x6e043E68F0d67b2fDcBaF50b14bA50c94A83578C;
        userAddresses[24] = 0x81542000E115f4632e6dD41f0D0e1c1AC777F9e9;
        userAddresses[25] = 0xEc5397A61bd8dE1B0aB8719a9e897eEc67BAD5C2;
        userAddresses[26] = 0xCc4D262A477e8D1dF5A85B00b230376697F774bD;
        userAddresses[27] = 0x67a5A9E9a0A6cfb6a73442b9811B141EA875D3B7;
        userAddresses[28] = 0xEBcC98573c3cd9b5B61900D1304DA938B5036a0d;
        userAddresses[29] = 0x1bDb97985913D699B0FBd1aAcF96d1F855d9E1d0;
        userAddresses[30] = 0xE5ce4Cf297919e96aDf2D32B05a93C42A36013Bd;
        userAddresses[31] = 0x82368563257B056Ae3d5eB9434C8AA4E0FA3526E;
        userAddresses[32] = 0x9a3b020A09a5eE27Ce172336Ae406DC01E4950Bf;
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
        require(address(syPresale.safeYieldConfig()) == address(syConfig), "Invalid config address");

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
        require(address(syStaking.configs()) == address(syConfig), "Invalid config address");
        require(address(syStaking.getCallback(0)) == address(syTokenDistributor), "Invalid callback");

        //validate lockup configurations
        require(address(syLockUp.configs()) == address(syConfig), "Invalid config address");
        require(address(syLockUp.sSayToken()) == address(syStaking), "Invalid sSafeToken token address");
        require(syLockUp.approvedVestingAgents(address(syStaking)) == true, "Staking contract not approved");
        require(syLockUp.approvedVestingAgents(SY_ADMIN) == true, "Admin not approved");

        //validate airdrop
        require(address(syAirdrop.sayToken()) == address(sayToken), "Invalid safeToken token address");
        require(address(syAirdrop.safeYieldConfigs()) == address(syConfig), "Invalid config address");
        require(syAirdrop.merkleRoot() == MERKLE_ROOT, "Invalid merkle root");

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
        require(address(syTokenDistributor.configs()) == address(syConfig), "Invalid config address");
    }
}
