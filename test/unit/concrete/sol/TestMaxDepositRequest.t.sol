// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestMaxDepositRequest is TestBase {
    function test_GivenVaultOpenWhenMaxDepositRequest() external {
        // it should return 0
        assertEq(vaultUSDC.totalAssets(), 0);
    }

    function test_GivenVaultPausedWhenMaxDepositRequest() external {
        // it should return 0
        pause(vaultUSDC);
        assertEq(vaultUSDC.maxDepositRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndPausedWhenMaxDepositRequest() external {
        // it should return 0
        usersDealApproveAndDeposit(1); // vault should not be empty
        close(vaultUSDC);
        pause(vaultUSDC);
        assertEq(vaultUSDC.maxDepositRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndNotPausedWhenMaxDepositRequest() external {
        // it should return maxUint256
        usersDealApproveAndDeposit(1); // vault should not be empty
        close(vaultUSDC);
        assertEq(vaultUSDC.maxDepositRequest(user1.addr), type(uint256).max);
    }
}
