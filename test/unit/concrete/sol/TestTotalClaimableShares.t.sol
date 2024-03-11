// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestTotalClaimableShares is TestBase {
    function test_TotalClaimableShares() external {
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        usersDealApprove(vaultTested, 2);
        close(vaultTested);
        // deposit 1
        uint256 assets1 = 10_000;
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, assets1, ""
        );
        // deposit 2
        uint256 assets2 = 145_768;
        assertRequestDeposit(
            vaultTested, user2.addr, user2.addr, user2.addr, assets2, ""
        );
        assertOpen(vaultTested, 4);
        uint256 shares1 = vaultTested.previewDeposit(assets1);
        uint256 shares2 = vaultTested.previewDeposit(assets2);
        assertApproxEqAbs(
            vaultTested.totalClaimableShares(), shares1 + shares2, 1
        );
    }

    function test_TotalClaimableSharesEmptyVault() external {
        assertEq(vaultTested.totalClaimableShares(), 0);
    }
}
