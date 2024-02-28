// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestPendingDepositRequest is TestBase {
    function test_GivenOwnerHasNotInteractedWithTheVaultWhenPendingDepositRequest() external {
        // it should return 0
        assertEq(vaultUSDC.pendingDepositRequest(user1.addr), 0, "Invalid pending deposit request");
    }

    function test_GivenAnOwnerWhoHasInteractedWithTheVaultWhenDepositRequest() external {
        // it should return the amount of pending deposit for his last deposit
        // request when pendingDepositRequest
        usersDealApproveAndDeposit(1);
        close(vaultUSDC);
        uint256 amount = 101;
        assertRequestDeposit(vaultUSDC, user1.addr, user1.addr, user1.addr, amount, "");
    }
}
