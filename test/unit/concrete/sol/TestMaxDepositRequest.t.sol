// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestMaxDepositRequest {
    function test_GivenVaultOpenWhenMaxDepositRequest() external {
        // it should return 0
    }

    function test_GivenVaultPausedWhenMaxDepositRequest() external {
        // it should return 0
    }

    function test_GivenVaultClosedAndPausedWhenMaxDepositRequest() external {
        // it should return 0
    }

    function test_GivenVaultClosedAndNotPausedWhenMaxDepositRequest() external {
        // it should return maxUint256
    }
}
