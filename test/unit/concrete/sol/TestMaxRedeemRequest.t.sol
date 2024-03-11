// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestMaxRedeemRequest is TestBase {
    function test_GivenVaultOpenWhenMaxRedeemRequest() external {
        // it should return 0
        assertEq(vaultTested.maxRedeemRequest(user1.addr), 0);
    }

    function test_GivenVaultPausedWhenMaxRedeemRequest() external {
        // it should return 0
        pause(vaultTested);
        assertEq(vaultTested.maxRedeemRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndPausedWhenMaxRedeemRequest() external {
        // it should return 0
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        pause(vaultTested);
        assertEq(vaultTested.maxRedeemRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndNotPausedWhenMaxRedeemRequest() external {
        // it should return maxUint256
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        assertEq(
            vaultTested.maxRedeemRequest(user1.addr),
            vaultTested.balanceOf(user1.addr)
        );
    }
}
