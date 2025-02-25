// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";
import { SafeYieldPresale, ISafeYieldPreSale } from "src/SafeYieldPresale.sol";
import { SafeYieldStaking, ISafeYieldStaking, Stake } from "src/SafeYieldStaking.sol";
import { SafeYieldVesting } from "src/SafeYieldVesting.sol";
import { SafeToken, ISafeToken } from "src/SafeToken.sol";

contract SafeYieldDeploymentMigrateUsers is Script {
    address public constant OLD_STAKING = 0xBF220A4C1Ae2367508de12E84BbadfFF6D5698E0;
    address public constant STAKING = 0x0Cea072f4490fAA57fcA58AA9339D4B71210bcd4; //!add new staking address
    address public constant SAY_TOKEN = 0x19D4b337B77b04256668679159E0b78A42fb0a1a;
    address public constant SY_ADMIN = 0x3e88e60894D081B27D180fcADd524365A3DE7Dd4;

    SafeToken public sayToken = SafeToken(SAY_TOKEN);
    ISafeYieldStaking public oldStaking = ISafeYieldStaking(OLD_STAKING);
    ISafeYieldStaking public syStaking = ISafeYieldStaking(STAKING);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(deployerPrivateKey);

        uint256 safeAllocated = sayToken.allocationLimits(SY_ADMIN);

        //admin to mint say to stake for users
        sayToken.mint(safeAllocated);

        //stake for OldStaking users
        _stakeForMultipleUsers(safeAllocated);

        vm.stopBroadcast();
    }

    function _stakeForMultipleUsers(uint256 totalStakedSay) internal {
        //approve total amounts to stake
        sayToken.approve(address(syStaking), totalStakedSay);

        (address[] memory userAddresses, uint128[] memory amounts) = getOldStakingUserAddresses();

        syStaking.stakeForMany(userAddresses, amounts, true);

        _assertMultipleUserStakeForNewStaking(userAddresses);
    }

    function _assertMultipleUserStakeForNewStaking(address[] memory users) internal view {
        uint256 numOfUsers = users.length;

        for (uint256 i; i < numOfUsers; i++) {
            //assert new stake amounts
            require(syStaking.getUserStake(users[i]).stakeAmount > 0, "Invalid user stake amount");
        }

        //say token config
        require(sayToken.totalSupply() == 20_000_000e18, "Total supply not reached");
    }

    function getOldStakingUserAddresses()
        internal
        view
        returns (address[] memory userAddresses, uint128[] memory userStakeAmounts)
    {
        userAddresses = new address[](36);
        userStakeAmounts = new uint128[](36);

        userAddresses[0] = 0x82368563257B056Ae3d5eB9434C8AA4E0FA3526E;
        userAddresses[1] = 0xE5ce4Cf297919e96aDf2D32B05a93C42A36013Bd;
        userAddresses[2] = 0x1bDb97985913D699B0FBd1aAcF96d1F855d9E1d0;
        userAddresses[3] = 0xEc5397A61bd8dE1B0aB8719a9e897eEc67BAD5C2;
        userAddresses[4] = 0xEBcC98573c3cd9b5B61900D1304DA938B5036a0d;
        userAddresses[5] = 0x67a5A9E9a0A6cfb6a73442b9811B141EA875D3B7;
        userAddresses[6] = 0xCc4D262A477e8D1dF5A85B00b230376697F774bD;
        userAddresses[7] = 0x81542000E115f4632e6dD41f0D0e1c1AC777F9e9;
        userAddresses[8] = 0xe8989b32996CB079823BC43c6D0D160aAf30CB7d;
        userAddresses[9] = 0x6e043E68F0d67b2fDcBaF50b14bA50c94A83578C;
        userAddresses[10] = 0xFaf790Ff539471763Da851d63AD1A47D0F95f2A6;
        userAddresses[11] = 0x439bE9BE6f5009577503BfEE25367a5fd36d76dF;
        userAddresses[12] = 0xaf5Ae7CdAff6f1f457bc88F0989c0AF7f583Ab43;
        userAddresses[13] = 0xA32851095944385b930713885f2af518e0b7e45C;
        userAddresses[14] = 0x28f0ee52A63d57f494D7968DBcf66156AfAEf3de;
        userAddresses[15] = 0x35434690bd439c8936e94B148246AE208Dfc9851;
        userAddresses[16] = 0x03Cbd99F5A7c39c7499273AbB8363b0372cc7930;
        userAddresses[17] = 0xD4d3E342902766344075D06c94391e61A9bB7e60;
        userAddresses[18] = 0x8B376f5e02090499c2c4fBd900E1bC18EF4961d4;
        userAddresses[19] = 0x3f6A905FF080c3e0A6307af4CFe9842ad87EBCeB;
        userAddresses[20] = 0x0d81aCc4a7F0b48874147EF7073EBC1bB3D2A7Af;
        userAddresses[21] = 0xfb59b257aF5518787E32D8DD1a8cf0DE13393385;
        userAddresses[22] = 0xD42cf8d4f72a6b26e13EFe43A198aaF05CB835ae;
        userAddresses[23] = 0x3e03B0593E125666Ba4B7479186b20FbD4146dF3;
        userAddresses[24] = 0x6501B7A416ed4d861129A4B2EFa90B364d4E776C;
        userAddresses[25] = 0x9a3b020A09a5eE27Ce172336Ae406DC01E4950Bf;
        userAddresses[26] = 0xa9E94416Aa43913c8E779Cf356bC0C6a250EA6Bf;
        userAddresses[27] = 0x3Dac0bDdfa0F9b3d86031A0bfbf7804030AB83b2;
        userAddresses[28] = 0x061Bc6f643038E4d6561aF4EBbc0B127cc5316cF;
        userAddresses[29] = 0xc3D5CdC556Bf7A012039194a5575486c212164a9;
        userAddresses[30] = 0x46BA2EbDE072bEa26fA4b54eEc6b6C39b5FEc10e;
        userAddresses[31] = 0xFb2afe0bA538f839D093197C1c324AB3Bc73d53f;
        userAddresses[32] = 0x6405f47Be0D616E7f59749cdAF8e8b180CaA18cB;
        userAddresses[33] = 0x3BD358b35b6Ff3cADf01Ac118b3d21Ee62E56C0C;
        userAddresses[34] = 0xEeE9Ef09B9D9dE0B8aA47A781bA7aCF87818C05f;
        userAddresses[35] = 0x12f6471bF62193467e0985CAD1747d077dfc0723;

        for (uint256 j; j < userAddresses.length; j++) {
            userStakeAmounts[j] = oldStaking.getUserStake(userAddresses[j]).stakeAmount;
        }
    }
}
