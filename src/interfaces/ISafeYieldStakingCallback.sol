// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISafeYieldStakingCallback {
    function handleActionBefore(address _user, bytes4 _selector) external;

    function handleActionAfter(address _user, bytes4 _selector) external;
}
