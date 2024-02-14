// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestClaimableDepositRequest {
    function test_GivenAnOwnerWhoHasNotInteractedWithTheVaultWhenClaimableDepositRequest() external {
        // it should return 0
    }

    function test_GivenAnOwnerWithAPendingRequestWhenClaimableDepositRequest() external {
        // it should return 0
    }

    function test_GivenAnOwnerWithAClaimableRequestWhenClaimableDepositRequest() external {
        // it should return the amount of the claimable request
        // it should not revert
    }
}
