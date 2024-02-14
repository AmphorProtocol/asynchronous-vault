//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    AsyncSynthVault,
    IAllowanceTransfer,
    IERC20,
    SafeERC20
} from "../../src/AsyncSynthVault.sol";

using SafeERC20 for IERC20;

contract TestVault is AsyncSynthVault {
    constructor(IAllowanceTransfer _permit2) AsyncSynthVault(_permit2) {}

    function getClaimableAssets() public view returns (uint256) {
        return claimableAssets;
    }

    function getClaimableShares() public view returns (uint256) {
        return claimableShares;
    }

    function getMaxDrawdown() public view returns (uint16) {
        return _maxDrawdown;
    }

    function getAsset() public view returns (IERC20) {
        return _asset;
    }
}
