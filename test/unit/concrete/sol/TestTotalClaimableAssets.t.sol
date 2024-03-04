// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestTotalClaimableAssets is TestBase {
    function test_TotalClaimableAssets() external {
        usersDealApproveAndDeposit(vaultTested, 2); // vault should not be empty
        assertClose(vaultTested);
        // deposit 1
        uint256 shares1 = vaultTested.balanceOf(user2.addr) / 2;
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, shares1, ""
        );
        // deposit 2
        uint256 shares2 = 145_768;
        assertRequestRedeem(
            vaultTested, user2.addr, user2.addr, user2.addr, shares2, ""
        );
        assertOpen(vaultTested, 1000);
        uint256 assets1 = vaultTested.previewRedeem(shares1);
        uint256 assets2 = vaultTested.previewRedeem(shares2);
        assertApproxEqAbs(
            vaultTested.totalClaimableAssets(), assets1 + assets2, 1
        );
    }

    function test_TotalClaimableAssetsEmptyVault() external {
        assertEq(vaultTested.totalClaimableAssets(), 0);
    }
}
