//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IBaseStrategyHandlerCEX } from "./interfaces/IBaseStrategyHandlerCEX.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract BaseStrategyHandlerCEX is IBaseStrategyHandlerCEX {
    address public override strategyController;
    address public fundManager;
    IERC20 public usdcToken;

    mapping(uint128 controllerStrategyId => uint256 positionId) internal strategyPositionId;
    uint128 public strategyCounts;

    error SYSH_NOT_CONTROLLER();
    error SY_B_SH_UNIMPLEMENTED();
    error SY_B_SH_INVALID_ADDRESS();

   

    modifier onlyController() {
        if (msg.sender != strategyController) revert SYSH_NOT_CONTROLLER();
        _;
    }

    constructor(address _strategyController, address _usdcToken, address _fundManager ) {
        if (_strategyController == address(0) || _usdcToken == address(0)) revert SY_B_SH_INVALID_ADDRESS();
        strategyController = _strategyController;
        fundManager = _fundManager;
        usdcToken = IERC20(_usdcToken);
    }

    function openStrategy(uint256 amount, uint128 strategyId,uint256 cexType, address trader) external payable virtual onlyController returns (bytes32) {
        revert SY_B_SH_UNIMPLEMENTED();
    }


    function exitStrategy(uint256 finalBalance,uint128 strategyId) external payable virtual onlyController {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function getStrategyPositionId(uint128 controllerStrategyId)
        external
        view
        virtual
        returns (uint256 id256, bytes32 idBytes32)
    {
        id256 = strategyPositionId[controllerStrategyId];
        idBytes32 = bytes32(id256);
    }
}
