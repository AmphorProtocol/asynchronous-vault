// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestClaimableDepositRequest is TestBase {
    function test_GivenAnOwnerWhoHasNotInteractedWithTheVaultWhenClaimableDepositRequest(
    )
        external
    {
        // it should return 0
        assertEq(vaultTested.claimableDepositRequest(user1.addr), 0);
    }

    function test_GivenAnOwnerWithAPendingRequestWhenClaimableDepositRequest()
        external
    {
        // it should return 0
        // it should not revert
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty

        close(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 1);
        assertEq(vaultTested.claimableDepositRequest(user1.addr), 0);
    }

    function test_GivenAnOwnerWithAClaimableRequestWhenClaimableDepositRequest()
        external
    {
        // it should return the amount of the claimable request
        // it should not revert
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 1, "");
        assertOpen(vaultTested, 10);
        // console.log(vaultTested.claimableDepositRequest(user1.addr));
        // //assertEq(vaultTested.claimableDepositRequest(user1.addr),
        // /*vaultTested.getClaimableAssets()*/); // TODO: fix this
        // assertEq(vaultTested.claimableDepositRequest(user1.addr), 437500000);
    }
}
