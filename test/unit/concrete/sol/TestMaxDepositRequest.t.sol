// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestMaxDepositRequest is TestBase {
    function test_GivenVaultOpenWhenMaxDepositRequest() external {
        // it should return 0
        assertEq(vaultTested.maxDepositRequest(user1.addr), 0);
    }

    function test_GivenVaultPausedWhenMaxDepositRequest() external {
        // it should return 0
        pause(vaultTested);
        assertEq(vaultTested.maxDepositRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndPausedWhenMaxDepositRequest() external {
        // it should return 0
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        pause(vaultTested);
        assertEq(vaultTested.maxDepositRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndNotPausedWhenMaxDepositRequest()
        external
    {
        // it should return maxUint256
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        assertEq(vaultTested.maxDepositRequest(user1.addr), type(uint256).max);
    }
}
