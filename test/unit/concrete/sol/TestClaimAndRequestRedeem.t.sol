// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, IERC20 } from "../../../Base.t.sol";
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
        vaultTested.claimAndRequestRedeem(10 ** 18, user1.addr, user1.addr, "");

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

    function test_GivenDifferentReceiverWhenClaimAndRequestRedeem() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        usersDealApproveAndRequestRedeem(vaultTested, 1);
        assertOpen(vaultTested, 0);
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 pendingRedeemBefore =
            vaultTested.pendingRedeemRequest(user2.addr);
        vm.prank(user1.addr);
        vaultTested.claimAndRequestRedeem(10 ** 18, user2.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 pendingRedeemAfter =
            vaultTested.pendingRedeemRequest(user2.addr);
        assertGt(sharesBefore, sharesAfter, "Shares of owner should decrease");

        assertLt(
            pendingRedeemBefore,
            pendingRedeemAfter,
            "Pending redeem of receiver should increase"
        );
    }

    function test_GivenDifferentReceiverAndOnBehalfWhenClaimAndRequestRedeem()
        external
    {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        usersDealApproveAndRequestRedeem(vaultTested, 1);
        assertOpen(vaultTested, 0);
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 pendingRedeemBefore =
            vaultTested.pendingRedeemRequest(user2.addr);
        vm.prank(user1.addr);
        vaultTested.approve(user3.addr, type(uint256).max);

        vm.prank(user3.addr);
        vaultTested.claimAndRequestRedeem(10 ** 18, user2.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 pendingRedeemAfter =
            vaultTested.pendingRedeemRequest(user2.addr);
        assertGt(sharesBefore, sharesAfter, "Shares of owner should decrease");

        assertLt(
            pendingRedeemBefore,
            pendingRedeemAfter,
            "Pending redeem of receiver should increase"
        );
    }
}
