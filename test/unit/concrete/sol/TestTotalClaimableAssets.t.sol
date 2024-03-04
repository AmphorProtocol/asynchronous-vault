// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestTotalClaimableAssets is TestBase {
    function test_TotalClaimableAssets() external {
        usersDealApproveAndDeposit(2); // vault should not be empty
        closeVaults();
        // deposit 1
        uint256 shares1 = 10000;
        assertRequestRedeem(vaultUSDC, user1.addr, user1.addr, user1.addr, shares1, "");
        // deposit 2
        uint256 shares2 = 145768;
        assertRequestRedeem(vaultUSDC, user2.addr, user2.addr, user2.addr, shares2, "");
        // assertOpen(vaultUSDC, 1000); // todo fix log error
        open(vaultUSDC, 1000);
        uint256 assets1 = vaultUSDC.previewRedeem(shares1);
        uint256 assets2 = vaultUSDC.previewRedeem(shares2);
        assertApproxEqAbs(vaultUSDC.totalClaimableAssets(), assets1 + assets2, 1);
    }

    function test_TotalClaimableAssetsEmptyVault() external {
        assertEq(vaultUSDC.totalClaimableAssets(), 0);
    }
}