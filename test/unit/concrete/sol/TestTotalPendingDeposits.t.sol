// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestTotalPendingDeposits is TestBase {
    function test_GivenVaultOpenWhenTotalPendingDeposits() external {
        // it should return 0
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        assertRequestDeposit(
            vaultUSDC, user1.addr, user1.addr, user1.addr, 100, ""
        );
        assertOpen(vaultUSDC, 0);
        assertEq(
            vaultUSDC.totalPendingDeposits(),
            0,
            "Invalid total pending deposits"
        );
    }

    function test_GivenVaultClosedWhenTotalPendingDeposits() external {
        // it should return underlying balance of the silo contract
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        assertRequestDeposit(
            vaultUSDC, user1.addr, user1.addr, user1.addr, 100, ""
        );
        assertEq(
            vaultUSDC.totalPendingDeposits(),
            100,
            "Invalid total pending deposits"
        );
    }
}
