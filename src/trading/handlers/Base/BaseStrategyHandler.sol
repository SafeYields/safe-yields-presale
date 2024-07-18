//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IBaseStrategyHandler } from "./interfaces/IBaseStrategyHandler.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract BaseStrategyHandler is IBaseStrategyHandler {
    string public override exchangeName;
    address public override strategyController;
    IERC20 public usdcToken;

    mapping(uint128 controllerStrategyId => uint256 positionId) internal strategyPositionId;

    error SYSH_NOT_CONTROLLER();
    error SY_B_SH_UNIMPLEMENTED();
    error SY_B_SH_INVALID_ADDRESS();

    modifier onlyController(address _caller) {
        if (_caller != strategyController) revert SYSH_NOT_CONTROLLER();
        _;
    }

    constructor(address _strategyController, address _usdcToken, string memory _exchangeName) {
        if (_strategyController == address(0) || _usdcToken == address(0)) revert SY_B_SH_INVALID_ADDRESS();
        strategyController = _strategyController;
        exchangeName = _exchangeName;
        usdcToken = IERC20(_usdcToken);
    }

    function openStrategy(bytes memory, bytes memory) external virtual onlyController(msg.sender) {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function cancelOrder(bytes memory) external virtual onlyController(msg.sender) {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function modifyStrategy(bytes memory) external virtual onlyController(msg.sender) {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function exitStrategy(bytes memory) external virtual onlyController(msg.sender) {
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
