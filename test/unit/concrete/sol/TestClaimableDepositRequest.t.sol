// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestClaimableDepositRequest is TestBase {
    function test_GivenAnOwnerWhoHasNotInteractedWithTheVaultWhenClaimableDepositRequest() external {
        // it should return 0
        assertEq(vaultUSDC.claimableDepositRequest(user1.addr), 0);
    }

    function test_GivenAnOwnerWithAPendingRequestWhenClaimableDepositRequest() external {
        // it should return 0
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        usersDealApproveAndRequestDeposit(1);
        assertEq(vaultUSDC.claimableDepositRequest(user1.addr), 0);
    }

    function test_GivenAnOwnerWithAClaimableRequestWhenClaimableDepositRequest() external {
        // it should return the amount of the claimable request
        // it should not revert
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        usersDealApproveAndRequestDeposit(1);
        open(vaultUSDC, 10);
        console.log(vaultUSDC.claimableDepositRequest(user1.addr));
        //assertEq(vaultUSDC.claimableDepositRequest(user1.addr), /*vaultUSDC.getClaimableAssets()*/); // TODO: fix this
        assertEq(vaultUSDC.claimableDepositRequest(user1.addr), 437500000);
    }
}
