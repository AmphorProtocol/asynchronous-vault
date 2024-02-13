//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    AsyncSynthVault,
    IAllowanceTransfer,
    IERC20
} from "../../src/AsyncSynthVault.sol";

contract TestAsyncVault is AsyncSynthVault {
    constructor(IAllowanceTransfer _permit2) AsyncSynthVault(_permit2) { }

    uint256 public claimableAssets;
    uint256 public claimableShares;
    uint16 public _maxDrawdown;
    IERC20 public _asset;
}
