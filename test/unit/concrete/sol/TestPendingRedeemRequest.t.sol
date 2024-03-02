// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestPendingDepositRequest is TestBase {
    function test_GivenOwnerHasNotInteractedWithTheVaultWhenPendingRedeemRequest(
    )
        external
    {
        // it should return 0
        assertEq(
            vaultTested.pendingRedeemRequest(user1.addr),
            0,
            "Invalid pending deposit request"
        );
    }

    function test_GivenAnOwnerWhoHasInteractedWithTheVaultWhenRedeemRequest()
        external
    {
        // it should return the amount of pending deposit for his last deposit
        // request when pendingDepositRequest
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        uint256 amount = 100;
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, amount, ""
        );
    }
}
