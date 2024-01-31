// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestDeposit {
    function test_WhenVaultIsClosed() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenVaultIsOpen() external {
        // it should not revert
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the minted shares amount
        // it should return the same value as the given (to the receiver) shares amount
        // it should increase the total supply of shares
        // it should return the same value as the one returned by previewDeposit
    }

    function test_WhenTheReceiverIsNotTheOwner() external {
        // it should not revert
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the minted shares amount
        // it should return the same value as the given (to the receiver) shares amount
        // it should increase the total supply of shares
        // it should return the same value as the one returned by previewDeposit
    }

    function test_WhenVaultIsEmpty() external {
        // it should not revert
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the minted shares amount
        // it should return the same value as the given (to the receiver) shares amount
        // it should increase the total supply of shares
        // it should return the same value as the one returned by previewDeposit
    }

    function test_WhenTheDepositAmountIs0() external {
        // it should not revert
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the minted shares amount
        // it should return the same value as the given (to the receiver) shares amount
        // it should increase the total supply of shares
        // it should return the same value as the one returned by previewDeposit
    }

    function test_WhenVaultIsOpenAndPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenVaultIsClosedAndPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenReceiverIsAddress0() external {
        // it should revert with ERC20InvalidReceiver
    }
}
