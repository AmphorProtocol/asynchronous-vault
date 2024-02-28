// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, AsyncSynthVault } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestRequestRedeem is TestBase {
    function test_GivenVaultOpenWhenRequestRedeem() external {
        // it should revert VaultIsOpen
        vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        vaultUSDC.requestRedeem(1, address(this), address(this), "");
    }

    function test_GivenVaultClosedAndPausedWhenRequestRedeem() external {
        // it should revert EnforcedPause
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);

        vm.startPrank(vaultUSDC.owner());
        vaultUSDC.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultUSDC.requestRedeem(1, address(this), address(this), "");
    }

    function test_GivenVaultOpenAndPausedWhenRequestRedeem() external {
        // it should revert EnforcedPause
        usersDealApproveAndDeposit(1);
        vm.prank(vaultUSDC.owner());
        vaultUSDC.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultUSDC.requestRedeem(1, address(this), address(this), "");
    }

    function test_GivenMsgSenderNotEqualOwnerWhenRequestRedeem() external {
        usersDealApproveAndDeposit(2);
        vm.startPrank(user2.addr);
        IERC20(vaultUSDC.asset()).approve(user1.addr, type(uint256).max);
        vm.stopPrank();
        assertClose(vaultUSDC);
        vm.prank(user2.addr);
        vaultUSDC.approve(user1.addr, type(uint256).max);
        vm.prank(user1.addr);
        vaultUSDC.requestRedeem(1, user1.addr, user2.addr, "");
        assertOpen(vaultUSDC, 0);
        assertClose(vaultUSDC);
        usersDealApprove(1);
    }

    function test_GivenReceiverHasClaimableBalanceWhenRequestRedeem()
        external
    {
        // it should revert with maxDepositRequest
        usersDealApproveAndDeposit(1);

        assertClose(vaultUSDC);
        vm.prank(user1.addr);
        vaultUSDC.requestRedeem(10, user1.addr, user1.addr, "");
        assertOpen(vaultUSDC, 0);
        assertClose(vaultUSDC);
        usersDealApprove(1);
        vm.startPrank(user1.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                AsyncSynthVault.MustClaimFirst.selector, user1.addr
            )
        );
        vaultUSDC.requestRedeem(5, user1.addr, user1.addr, "");
    }

    function test_WhenRequestRedeemSucceed() external {
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        assertRequestRedeem(
            vaultUSDC, user1.addr, user1.addr, user1.addr, 56, ""
        );
    }

    function test_GivenOwnerHasClaimableBalanceButNotReceiverWhenRequestRedeem()
        external
    {
        // it should succeed
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        assertRequestRedeem(
            vaultUSDC, user1.addr, user1.addr, user1.addr, 1, ""
        );
        assertOpen(vaultUSDC, 0);
        assertClose(vaultUSDC);
        usersDealApprove(4);
        assertRequestRedeem(
            vaultUSDC, user1.addr, user1.addr, user4.addr, 1, ""
        );
    }

    function test_GivenOwnerHaveNotEnoughApprovalBalanceWhenRequestRedeem()
        external
    {
        // it should revert with ERC20InsufficientAllowance
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        vm.startPrank(user2.addr);
        vm.expectRevert();
        vaultUSDC.requestRedeem(1, user1.addr, user2.addr, "");
        vm.stopPrank();
    }

    function test_GivenOwnerHaveNotEnoughAssetsBalanceWhenRequestRedeem()
        external
    {
        // it should revert with ERC20InsufficientBalance
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        vm.startPrank(user2.addr);
        vm.expectRevert();
        vaultUSDC.requestRedeem(100, user2.addr, user2.addr, "");
    }

    function test_GivenDataParamSubmittedAndInvalidSelectorWhenRequestRedeem()
        external
    {
        // it should revert with ReceiverFailed
        // it todo check ERC7540Receiver (and ReceiverFailed)
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vaultUSDC.requestRedeem(1, user1.addr, user1.addr, "0x1234");
    }
}
