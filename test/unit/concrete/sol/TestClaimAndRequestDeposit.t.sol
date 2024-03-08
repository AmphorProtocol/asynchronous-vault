// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, IERC20 } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TestClaimAndRequestDeposit is TestBase {
    function test_WhenClaimAndRequestDeposit() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 1);
        assertOpen(vaultTested, 0);
        //vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        //decreaseDepositRequest(vaultTested, user1, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 pendingDepositBefore =
            vaultTested.pendingDepositRequest(user1.addr);
        vm.prank(user1.addr);
        vaultTested.claimAndRequestDeposit(10 ** 18, user1.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 pendingDepositAfter =
            vaultTested.pendingDepositRequest(user1.addr);
        assertLt(
            sharesBefore, sharesAfter, "Shares of receiver should increase"
        );
        assertLt(
            pendingDepositBefore,
            pendingDepositAfter,
            "Pending deposit of msg.sender should increase"
        );
    }

    function test_GivenDifferentReceiverWhenClaimAndRequestDeposit() external {
        usersDealApproveAndDeposit(vaultTested, 3);
        assertClose(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 3);
        assertOpen(vaultTested, 0);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user2.addr);
        uint256 pendingDepositBefore =
            vaultTested.pendingDepositRequest(user2.addr);
        vm.prank(user1.addr);
        vaultTested.claimAndRequestDeposit(10 ** 18, user2.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user2.addr);
        uint256 pendingDepositAfter =
            vaultTested.pendingDepositRequest(user2.addr);
        assertLt(
            sharesBefore, sharesAfter, "Shares of receiver should increase"
        );
        assertLt(
            pendingDepositBefore,
            pendingDepositAfter,
            "Pending deposit of msg.sender should increase"
        );
    }

    function test_GivenDifferentReceiverAndOnBehalfWhenClaimAndRequestDeposit()
        external
    {
        usersDealApproveAndDeposit(vaultTested, 3);
        assertClose(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 3);
        assertOpen(vaultTested, 0);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user2.addr);
        uint256 sharesBeforeMsgSender = vaultTested.balanceOf(user1.addr);
        uint256 pendingDepositBefore =
            vaultTested.pendingDepositRequest(user2.addr);
        vm.prank(user1.addr);
        underlying.approve(user3.addr, type(uint256).max);
        vm.prank(user3.addr);
        vaultTested.claimAndRequestDeposit(10 ** 18, user2.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user2.addr);
        uint256 pendingDepositAfter =
            vaultTested.pendingDepositRequest(user2.addr);
        uint256 sharesAfterMsgSender = vaultTested.balanceOf(user1.addr);
        assertLt(
            sharesBefore, sharesAfter, "Shares of receiver should increase"
        );
        assertLt(
            pendingDepositBefore,
            pendingDepositAfter,
            "Pending deposit of msg.sender should increase"
        );
        assertEq(
            sharesBeforeMsgSender,
            sharesAfterMsgSender,
            "Shares of msg.sender should not change"
        );
    }

    function test_DifferentReceiverAndOnBehalfWithoutAllowanceWhenClaimAndRequestDeposit(
    )
        external
    {
        usersDealApproveAndDeposit(vaultTested, 3);
        assertClose(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 3);
        assertOpen(vaultTested, 0);
        assertClose(vaultTested);
        vm.prank(user3.addr);
        vm.expectRevert();
        vaultTested.claimAndRequestDeposit(10 ** 18, user2.addr, user1.addr, "");
    }
}
