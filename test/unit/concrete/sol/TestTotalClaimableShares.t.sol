// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestTotalClaimableShares is TestBase {
    function test_TotalClaimableShares() external {
        usersDealApproveAndDeposit(1); // vault should not be empty
        usersDealApprove(2);
        closeVaults();
        // deposit 1
        uint256 assets1 = 10000;
        assertRequestDeposit(vaultUSDC, user1.addr, user1.addr, user1.addr, assets1, "");
        // deposit 2
        uint256 assets2 = 145768;
        assertRequestDeposit(vaultUSDC, user2.addr, user2.addr, user2.addr, assets2, "");
        open(vaultUSDC, 1000);
        uint256 shares1 = vaultUSDC.previewDeposit(assets1);
        uint256 shares2 = vaultUSDC.previewDeposit(assets2);
        assertEq(vaultUSDC.totalClaimableShares(), shares1 + shares2);
    }
}