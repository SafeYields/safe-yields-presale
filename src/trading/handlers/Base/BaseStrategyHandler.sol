//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IBaseStrategyHandler } from "./interfaces/IBaseStrategyHandler.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract BaseStrategyHandler is IBaseStrategyHandler {
    string public override exchangeName;
    address public override strategyController;
    address public fundManager;
    IERC20 public usdcToken;

    mapping(uint128 controllerStrategyId => uint256 positionId) internal strategyPositionId;
    uint128 public strategyCounts;
    //!mapping to target

    error SYSH_NOT_CONTROLLER();
    error SY_B_SH_UNIMPLEMENTED();
    error SY_B_SH_INVALID_ADDRESS();

    error SY_HDL__POSITION_EXIST();
    error SY_HDL__CALL_FAILED();

    modifier onlyController() {
        if (msg.sender != strategyController) revert SYSH_NOT_CONTROLLER();
        _;
    }

    constructor(address _strategyController, address _usdcToken, address _fundManager, string memory _exchangeName) {
        if (_strategyController == address(0) || _usdcToken == address(0)) revert SY_B_SH_INVALID_ADDRESS();
        strategyController = _strategyController;
        fundManager = _fundManager;
        exchangeName = _exchangeName;
        usdcToken = IERC20(_usdcToken);
    }

    function openStrategy(bytes memory, bytes memory) external payable virtual onlyController returns (bytes32) {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function cancelOrder(bytes memory) external virtual onlyController {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function modifyStrategy(bytes memory) external payable virtual onlyController {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    function exitStrategy(uint128, bytes memory) external payable virtual onlyController {
        revert SY_B_SH_UNIMPLEMENTED();
    }

    //function getStrategies() external view returns()

    function getStrategyPositionId(uint128 controllerStrategyId)
        external
        view
        virtual
        returns (uint256 id256, bytes32 idBytes32)
    {
        id256 = strategyPositionId[controllerStrategyId];
        idBytes32 = bytes32(id256);
    }

    function executeData(address target, bytes memory handlerData) external onlyController {
        (bool success,) = address(target).call(handlerData);
    }
}
