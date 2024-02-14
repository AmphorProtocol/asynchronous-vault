// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestRequestDeposit {
    function test_GivenVaultOpenAndNotPausedWhenRequestDeposit() external {
        // it should revert VaultIsOpen
    }

    function test_GivenVaultClosedAndPausedWhenRequestDeposit() external {
        // it should revert EnforcedPause
    }

    function test_GivenVaultOpenAndPausedWhenRequestDeposit() external {
        // it should revert EnforcedPause
    }

    function test_GivenMsgSenderNotEqualOwnerWhenRequestDeposit() external {
        // it should revert NotOwner
    }

    function test_GivenReceiverHasClaimableBalanceWhenRequestDeposit() external {
        // it should revert with maxDepositRequest
    }

    function test_WhenRequestDepositSucceed() external {
        // it should decrease the owner underlying balance by the specified value
        // it should increase the vault underlying balance by the specified value
        // it should increase pendingDepositRequest balance of receiver by the specified value
        // it should not modify the owner pendingDepositRequest balance
        // it should emit DepositRequest event
    }

    function test_GivenOwnerHasClaimableBalanceButNotReceiverWhenRequestDeposit() external {
        // it should succeed
    }

    function test_GivenOwnerHaveNotEnoughApprovalBalanceWhenRequestDeposit() external {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_GivenOwnerHaveNotEnoughAssetsBalanceWhenRequestDeposit() external {
        // it should revert with ERC20InsufficientBalance
    }

    function test_GivenDataParamSubmittedAndInvalidSelectorWhenRequestDeposit() external {
        // it should revert with ReceiverFailed
        // it todo check ERC7540Receiver (and ReceiverFailed)
    }
}
