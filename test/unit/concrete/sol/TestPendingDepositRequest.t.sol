// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestPendingDepositRequest {
    function test_GivenAnOwnerWhoHasNotInteractedWithTheVaultWhenPendingDepositRequest() external {
        // it should return 0
    }

    function test_GivenAnOwnerWhoHasInteractedWithTheVault() external {
        // it should return the amount of pending deposit for his last deposit request when pendingDepositRequest
    }
}
