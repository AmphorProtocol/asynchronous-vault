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
	uint256 pendingDepositBefore = vaultTested.pendingDepositRequest(user1.addr);
	vm.prank(user1.addr);
	vaultTested.claimAndRequestDeposit(10 ** 18, user1.addr, user1.addr,"");
	
	uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
	uint256 pendingDepositAfter = vaultTested.pendingDepositRequest(user1.addr);
	assertLt(sharesBefore, sharesAfter, "Shares of receiver should increase");
	assertLt(pendingDepositBefore, pendingDepositAfter, "Pending deposit of msg.sender should increase");
	
    }
    function test_WhenClaimAndRequestDepositDifferentReceiver() external {
        
        usersDealApproveAndDeposit(vaultTested, 3);
        assertClose(vaultTested);
	usersDealApproveAndRequestDeposit(vaultTested, 3);
	assertOpen(vaultTested, 0);
        //vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        //decreaseDepositRequest(vaultTested, user1, 1);
	assertClose(vaultTested);
	uint256 sharesBefore = vaultTested.balanceOf(user2.addr);
	uint256 pendingDepositBefore = vaultTested.pendingDepositRequest(user2.addr);
	vm.prank(user1.addr);
	vaultTested.claimAndRequestDeposit(10 ** 18, user2.addr, user1.addr,"");
	
	uint256 sharesAfter = vaultTested.balanceOf(user2.addr);
	uint256 pendingDepositAfter = vaultTested.pendingDepositRequest(user2.addr);
	assertLt(sharesBefore, sharesAfter, "Shares of receiver should increase");
	assertLt(pendingDepositBefore, pendingDepositAfter, "Pending deposit of msg.sender should increase");
}
    function test_WhenClaimAndRequestDepositDifferentReceiverAndOnBehalf() external {
        
        usersDealApproveAndDeposit(vaultTested, 3);
        assertClose(vaultTested);
	usersDealApproveAndRequestDeposit(vaultTested, 3);
	assertOpen(vaultTested, 0);
        //vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        //decreaseDepositRequest(vaultTested, user1, 1);
	assertClose(vaultTested);
	uint256 sharesBefore = vaultTested.balanceOf(user2.addr);
	uint256 pendingDepositBefore = vaultTested.pendingDepositRequest(user2.addr);
	vm.prank(user1.addr);
	underlying.approve(user3.addr, type(uint256).max);
	vm.prank(user3.addr);
	vaultTested.claimAndRequestDeposit(10 ** 18, user2.addr, user1.addr,"");
	
	uint256 sharesAfter = vaultTested.balanceOf(user2.addr);
	uint256 pendingDepositAfter = vaultTested.pendingDepositRequest(user2.addr);
	assertLt(sharesBefore, sharesAfter, "Shares of receiver should increase");
	assertLt(pendingDepositBefore, pendingDepositAfter, "Pending deposit of msg.sender should increase");
}
/*
/*
    function test_GivenVaultClosedAndPausedWhenDecreaseDepositRequest()
        external
    {
        // it should revert with `EnforcedPause`
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        vm.prank(vaultTested.owner());
        vaultTested.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        decreaseDepositRequest(vaultTested, user1, 1);
    }

    function test_GivenVaultStateOkAndAssetsTooHighWhenDecreaseDepositRequest()
        external
    {
        // it should revert if assets is higher than the owner deposit request
        // balance
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        uint256 userBalance = IERC20(vaultTested.asset()).balanceOf(user1.addr);
        vm.expectRevert();
        decreaseDepositRequest(vaultTested, user1, userBalance + 1);
    }

    function test_GivenVaultStateOkAndReceiverIsNotOwnerWhenDecreaseDepositRequest(
    )
        external
    {
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        assertDecreaseDeposit(vaultTested, user2.addr);
    }

    function test_GivenVaultStateOkAndReceiverIsOwnerWhenDecreaseDepositRequest(
    )
        external
    {
        // it should pass same as above
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        assertDecreaseDeposit(vaultTested, user1.addr);
    }*/
}
