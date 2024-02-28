// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestTotalPendingRedeems is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(1);
    }

    function test_GivenVaultOpenWhenTotalPendingRedeems() external {
        // it should return 0
        closeVaults();
        requestRedeem(vaultUSDC, user1, 1, "");
        assertOpen(vaultUSDC, 0);
        assertEq(vaultUSDC.totalPendingRedeems(), 0);
    }

    function test_GivenVaultClosedWhenTotalPendingRedeems() external {
        // it should return shares balance of vault
        closeVaults();
        requestRedeem(vaultUSDC, user1, 1, "");
        assertEq(vaultUSDC.totalPendingRedeems(), 1);
    }
}
