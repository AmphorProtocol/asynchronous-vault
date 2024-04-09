// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestTotalPendingDeposits is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(vaultTested, 1);
    }

    function test_GivenVaultOpenWhenTotalPendingDeposits() external {
        // it should return 0
        assertClose(vaultTested);
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, 100, ""
        );
        assertOpen(vaultTested, 0);
        assertEq(
            vaultTested.totalPendingDeposits(),
            0,
            "Invalid total pending deposits"
        );
    }

    function test_GivenVaultClosedWhenTotalPendingDeposits() external {
        // it should return underlying balance of the silo contract
        assertClose(vaultTested);
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, 100, ""
        );
        assertEq(
            vaultTested.totalPendingDeposits(),
            100,
            "Invalid total pending deposits"
        );
    }
}
