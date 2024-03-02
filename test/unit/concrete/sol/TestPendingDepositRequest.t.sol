// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestPendingDepositRequest is TestBase {
    function test_GivenOwnerHasNotInteractedWithTheVaultWhenPendingDepositRequest(
    )
        external
    {
        // it should return 0
        assertEq(
            vaultTested.pendingDepositRequest(user1.addr),
            0,
            "Invalid pending deposit request"
        );
    }

    function test_GivenAnOwnerWhoHasInteractedWithTheVaultWhenDepositRequest()
        external
    {
        // it should return the amount of pending deposit for his last deposit
        // request when pendingDepositRequest
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        uint256 amount = 101;
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, amount, ""
        );
    }
}
