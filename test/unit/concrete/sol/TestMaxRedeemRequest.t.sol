// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestMaxRedeemRequest is TestBase {
    function test_GivenVaultOpenWhenMaxRedeemRequest() external {
        // it should return 0
        assertEq(vaultUSDC.maxRedeemRequest(user1.addr), 0);
    }

    function test_GivenVaultPausedWhenMaxRedeemRequest() external {
        // it should return 0
        pause(vaultUSDC);
        assertEq(vaultUSDC.maxRedeemRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndPausedWhenMaxRedeemRequest() external {
        // it should return 0
        usersDealApproveAndDeposit(1); // vault should not be empty
        close(vaultUSDC);
        pause(vaultUSDC);
        assertEq(vaultUSDC.maxRedeemRequest(user1.addr), 0);
    }

    function test_GivenVaultClosedAndNotPausedWhenMaxRedeemRequest() external {
        // it should return maxUint256
        usersDealApproveAndDeposit(1); // vault should not be empty
        close(vaultUSDC);
        assertEq(vaultUSDC.maxRedeemRequest(user1.addr), vaultUSDC.balanceOf(user1.addr));
    }
}
