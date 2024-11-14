// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC4626 } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICEXVault is IERC4626 {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    function maxTotalDeposit() external view returns (uint256);
    function depositsPaused() external view returns (bool);
    function withdrawalsPaused() external view returns (bool);
    function fundsInTrading() external view returns (uint256);
    function controller() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                        CORE VAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) external returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fundStrategy(address trader, uint256 amount) external ;
    function returnStrategyFunds(address trader, uint256 amount, int256 pnl) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setMaxTotalDeposit(uint256 newMax) external;
    function setController(address newController) external;
    function setWithdrawalsPaused(bool paused) external;
    function pauseAll() external;
}