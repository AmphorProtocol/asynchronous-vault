// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, AsyncSynthVault } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

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
        vaultUSDC;
        revert("Test not implemented");
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
                AsyncSynthVault.ExceededMaxDepositRequest.selector,
                user1.addr,
                1,
                0
            )
        );
        vaultUSDC.requestDeposit(1, user1.addr, user1.addr, "");
    }

    function test_WhenRequestDepositSucceed() external {
        // it should decrease the owner underlying balance by the specified
        // value
        // it should increase the vault underlying balance by the specified
        // value
        // it should increase pendingDepositRequest balance of receiver by the
        // specified value
        // it should not modify the owner pendingDepositRequest balance
        // it should emit DepositRequest event
    }

    function test_GivenOwnerHasClaimableBalanceButNotReceiverWhenRequestDeposit(
    )
        external
    {
        // it should succeed
    }

    function test_GivenOwnerHaveNotEnoughApprovalBalanceWhenRequestDeposit()
        external
    {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_GivenOwnerHaveNotEnoughAssetsBalanceWhenRequestDeposit()
        external
    {
        // it should revert with ERC20InsufficientBalance
    }

    function test_GivenDataParamSubmittedAndInvalidSelectorWhenRequestDeposit()
        external
    {
        // it should revert with ReceiverFailed
        // it todo check ERC7540Receiver (and ReceiverFailed)
    }
}
