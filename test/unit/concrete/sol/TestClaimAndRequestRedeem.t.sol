// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, IERC20 } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TestClaimAndRequestRedeem is TestBase {
    function test_WhenClaimAndRequestRedeem() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        usersDealApproveAndRequestRedeem(vaultTested, 1);
        assertOpen(vaultTested, 0);
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 assetsBefore = underlying.balanceOf(user1.addr);
        uint256 pendingRedeemBefore =
            vaultTested.pendingRedeemRequest(user1.addr);
        vm.prank(user1.addr);
        vaultTested.requestRedeem(sharesBefore / 2, user1.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 assetsAfter = underlying.balanceOf(user1.addr);
        uint256 pendingRedeemAfter =
            vaultTested.pendingRedeemRequest(user1.addr);
        assertGt(sharesBefore, sharesAfter, "Shares of owner should decrease");
        assertLt(
            assetsBefore, assetsAfter, "Assets of receiver should increase"
        );
        assertLt(
            pendingRedeemBefore,
            pendingRedeemAfter,
            "Pending redeem of msg.sender should increase"
        );
    }

    function test_WhenClaimAndRequestRedeemWhenNothingToClaim() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        assertOpen(vaultTested, 0);
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 assetsBefore = underlying.balanceOf(user1.addr);
        uint256 pendingRedeemBefore =
            vaultTested.pendingRedeemRequest(user1.addr);
        vm.prank(user1.addr);
        vaultTested.requestRedeem(sharesBefore / 2, user1.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 assetsAfter = underlying.balanceOf(user1.addr);
        uint256 pendingRedeemAfter =
            vaultTested.pendingRedeemRequest(user1.addr);
        assertGt(sharesBefore, sharesAfter, "Shares of owner should decrease");
        assertEq(
            assetsBefore, assetsAfter, "Assets of receiver should stay the same"
        );
        assertLt(
            pendingRedeemBefore,
            pendingRedeemAfter,
            "Pending redeem of msg.sender should increase"
        );
    }
}
