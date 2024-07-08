// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IExchangeRouter } from "./interfaces/IExchangeRouter.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract GMXHandler is Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS AND IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IExchangeRouter public immutable exchangeRouter;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SY__INVALID_ADDRESS();

    constructor(address _exchangeRouter, address protocolAdmin) Ownable(protocolAdmin) {
        if (_exchangeRouter == address(0) || protocolAdmin == address(0)) revert SY__INVALID_ADDRESS();

        exchangeRouter = IExchangeRouter(_exchangeRouter);
    }

    //TODO:
    function createOrder() external { }
}
