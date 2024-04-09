// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, AsyncVault } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestRequestRedeem is TestBase {
    function test_GivenVaultOpenWhenRequestRedeem() external {
        // it should revert VaultIsOpen
        vm.expectRevert(SyncVault.VaultIsOpen.selector);
        vaultTested.requestRedeem(1, address(this), address(this), "");
    }

    function test_GivenVaultClosedAndPausedWhenRequestRedeem() external {
        // it should revert EnforcedPause
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);

        vm.startPrank(vaultTested.owner());
        vaultTested.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultTested.requestRedeem(1, address(this), address(this), "");
    }

    function test_GivenVaultOpenAndPausedWhenRequestRedeem() external {
        // it should revert EnforcedPause
        usersDealApproveAndDeposit(vaultTested, 1);
        vm.prank(vaultTested.owner());
        vaultTested.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultTested.requestRedeem(1, address(this), address(this), "");
    }

    function test_GivenMsgSenderNotEqualOwnerWhenRequestRedeem() external {
        usersDealApproveAndDeposit(vaultTested, 2);
        vm.startPrank(user2.addr);
        IERC20(vaultTested.asset()).approve(user1.addr, type(uint256).max);
        vm.stopPrank();
        assertClose(vaultTested);
        vm.prank(user2.addr);
        vaultTested.approve(user1.addr, type(uint256).max);
        vm.prank(user1.addr);
        vaultTested.requestRedeem(1, user1.addr, user2.addr, "");
        assertOpen(vaultTested, 0);
        assertClose(vaultTested);
        usersDealApprove(vaultTested, 1);
    }

    function test_WhenRequestRedeemSucceed() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, 56, ""
        );
    }

    function test_GivenOwnerHasClaimableBalanceButNotReceiverWhenRequestRedeem()
        external
    {
        // it should succeed
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, 1, ""
        );
        assertOpen(vaultTested, 0);
        assertClose(vaultTested);
        usersDealApprove(vaultTested, 4);
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user4.addr, 1, ""
        );
    }

    function test_GivenOwnerHaveNotEnoughApprovalBalanceWhenRequestRedeem()
        external
    {
        // it should revert with ERC20InsufficientAllowance
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        vm.startPrank(user2.addr);
        vm.expectRevert();
        vaultTested.requestRedeem(1, user1.addr, user2.addr, "");
        vm.stopPrank();
    }

    function test_GivenOwnerHaveNotEnoughAssetsBalanceWhenRequestRedeem()
        external
    {
        // it should revert with ERC20InsufficientBalance
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        vm.startPrank(user2.addr);
        vm.expectRevert();
        vaultTested.requestRedeem(100, user2.addr, user2.addr, "");
    }

    function test_GivenDataParamSubmittedAndInvalidSelectorWhenRequestRedeem()
        external
    {
        // it should revert with ReceiverFailed
        // it todo check ERC7540Receiver (and ReceiverFailed)
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vaultTested.requestRedeem(1, user1.addr, user1.addr, "0x1234");
    }
}
