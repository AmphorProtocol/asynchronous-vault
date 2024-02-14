// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestRequestRedeem {
    function test_GivenVaultClosedAndNotPausedWhenRequestRedeem() external {
        // it should decrease owner shares balance by shares param
        // it should decrease shares total supply by shares param
        // it should create a pending redeem request for the receiver
        // it should emit RedeemRequest
    }

    function test_GivenVaultOpenAndNotPausedWhenRequestRedeem() external {
        // it should revert VaultIsOpen
    }

    function test_GivenVaultClosedAndPausedWhenRequestRedeem() external {
        // it should revert EnforcedPause
    }

    function test_GivenVaultOpenAndPausedWhenRequestRedeem() external {
        // it should revert EnforcedPause
    }

    function test_GivenMsgSenderNotEqualOwnerWhenRequestRedeem() external {
        // it should revert NotOwner
    }

    function test_GivenReceiverHasClaimableBalanceWhenRequestRedeem() external {
        // it should revert with maxRedeemRequest
    }

    function test_WhenRequestRedeemSucceed() external {
        // it should decrease the owner shares balance by the specified value
        // it should increase the vault shares balance by the specified value
        // it should increase pendingRedeemRequest balance of receiver by the specified value
        // it should not modify the owner pendingRedeemRequest balance
        // it should emit RedeemRequest event
    }

    function test_GivenOwnerHasClaimableBalanceButNotReceiverWhenRequestRedeem() external {
        // it should succeed
    }

    function test_GivenOwnerHaveNotEnoughAssetsBalanceWhenRequestRedeem() external {
        // it should revert with ERC20InsufficientBalance
    }

    function test_GivenOwnerHaveNotEnoughApprovalBalanceWhenRequestRedeem() external {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_GivenDataParamSubmittedAndInvalidSelectorWhenRequestRedeem() external {
        // it should revert with ReceiverFailed
        // it todo check ERC7540Receiver (and ReceiverFailed)
    }
}
