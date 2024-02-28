// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, AsyncSynthVault } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestRequestDeposit is TestBase {
    function test_GivenVaultOpenWhenRequestDeposit() external {
        // it should revert VaultIsOpen
        vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        vaultUSDC.requestDeposit(1, address(this), address(this), "");
    }

    function test_GivenVaultClosedAndPausedWhenRequestDeposit() external {
        // it should revert EnforcedPause
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);

        vm.startPrank(vaultUSDC.owner());
        vaultUSDC.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultUSDC.requestDeposit(1, address(this), address(this), "");
    }

    function test_GivenVaultOpenAndPausedWhenRequestDeposit() external {
        // it should revert EnforcedPause
        usersDealApproveAndDeposit(1);
        vm.prank(vaultUSDC.owner());
        vaultUSDC.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultUSDC.requestDeposit(1, address(this), address(this), "");
    }

    function test_GivenMsgSenderNotEqualOwnerWhenRequestDeposit() external {
        usersDealApproveAndDeposit(2);
        vm.startPrank(user2.addr);
        IERC20(vaultUSDC.asset()).approve(user1.addr, type(uint256).max);
        vm.stopPrank();
        assertClose(vaultUSDC);
        vm.prank(user1.addr);
        vaultUSDC.requestDeposit(1, user1.addr, user2.addr, "");
        assertOpen(vaultUSDC, 0);
        assertClose(vaultUSDC);
        usersDealApprove(1);
    }

    function test_GivenReceiverHasClaimableBalanceWhenRequestDeposit()
        external
    {
        // it should revert with maxDepositRequest
        usersDealApproveAndDeposit(1);

        assertClose(vaultUSDC);
        vm.prank(user1.addr);
        vaultUSDC.requestDeposit(1, user1.addr, user1.addr, "");
        assertOpen(vaultUSDC, 0);
        assertClose(vaultUSDC);
        usersDealApprove(1);
        vm.startPrank(user1.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                AsyncSynthVault.MustClaimFirst.selector, user1.addr
            )
        );
        vaultUSDC.requestDeposit(1, user1.addr, user1.addr, "");
    }

    function test_WhenRequestDepositSucceed() external {
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        assertRequestDeposit(
            vaultUSDC, user1.addr, user1.addr, user1.addr, 56, ""
        );
    }

    function test_GivenOwnerHasClaimableBalanceButNotReceiverWhenRequestDeposit(
    )
        external
    {
        // it should succeed
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        assertRequestDeposit(
            vaultUSDC, user1.addr, user1.addr, user1.addr, 56, ""
        );
        assertOpen(vaultUSDC, 0);
        assertClose(vaultUSDC);
        usersDealApprove(4);
        assertRequestDeposit(
            vaultUSDC, user1.addr, user1.addr, user4.addr, 56, ""
        );
    }

    function test_GivenOwnerHaveNotEnoughApprovalBalanceWhenRequestDeposit()
        external
    {
        // it should revert with ERC20InsufficientAllowance
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        vm.startPrank(user2.addr);
        vm.expectRevert();
        vaultUSDC.requestDeposit(1, user1.addr, user2.addr, "");
        vm.stopPrank();
    }

    function test_GivenOwnerHaveNotEnoughAssetsBalanceWhenRequestDeposit()
        external
    {
        // it should revert with ERC20InsufficientBalance
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        vm.startPrank(user2.addr);
        vm.expectRevert();
        vaultUSDC.requestDeposit(100, user2.addr, user2.addr, "");
    }

    function test_GivenDataParamSubmittedAndInvalidSelectorWhenRequestDeposit()
        external
    {
        // it should revert with ReceiverFailed
        // it todo check ERC7540Receiver (and ReceiverFailed)
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vaultUSDC.requestDeposit(1, user1.addr, user1.addr, "0x1234");
    }
}
