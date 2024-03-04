// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestTotalPendingRedeems is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(vaultTested, 1);
    }

    function test_GivenVaultOpenWhenTotalPendingRedeems() external {
        // it should return 0
        assertClose(vaultTested);
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, 100, ""
        );
        assertOpen(vaultTested, 0);
        assertEq(
            vaultTested.totalPendingRedeems(), 0, "Invalid total pending redeem"
        );
    }

    function test_GivenVaultClosedWhenTotalPendingRedeems() external {
        // it should return underlying balance of the silo contract
        assertClose(vaultTested);
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, 100, ""
        );
        assertEq(
            vaultTested.totalPendingRedeems(),
            100,
            "Invalid total pending redeem"
        );
    }
}
