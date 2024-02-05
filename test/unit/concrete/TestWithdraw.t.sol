// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestWithdraw {
    function test_WhenWithdrawGivenVaultClosed() external {
        // it should revert with ERC4626ExceededMaxWithdraw
    }

    function test_WhenWithdrawGivenVaultOpen() external {
        // it should revert if the withdraw amount provided by the owner is higher than his shares (converted to assets) balance
        // it should increase the underlying balance of the owner
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by the withdraw amount
        // it should decrease the balance of shares of the receiver by the withdraw amount converted in shares
        // it should return the same value as the one returned by previewWithdraw
        // it should return the same value as the burned (to the owner) shares amount
        // it should decrease the total supply of shares by the value returned by previewWithdraw
        // it should take the shares amount returned by previewWithdraw to the owner
    }

    function test_WhenWithdrawGivenVaultOpenGivenReceiverNotEqualOwner() external {
        // it should revert if the withdraw amount provided by the owner is higher than his shares (converted to assets) balance
        // it should increase the underlying balance of the owner
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by the withdraw amount
        // it should decrease the balance of shares of the receiver by the withdraw amount converted in shares
        // it should return the same value as the one returned by previewWithdraw
        // it should return the same value as the burned (to the owner) shares amount
        // it should decrease the total supply of shares by the value returned by previewWithdraw
        // it should take the shares amount returned by previewWithdraw to the owner
    }

    function test_WhenWithdrawGivenVaultOpenGivenVaultEmpty() external {
        // it should revert if the withdraw amount provided by the owner is higher than 0
    }

    function test_WhenWithdrawGivenVaultOpenGivenWithdrawAmountIs0() external {
        // it should revert if the withdraw amount provided by the owner is higher than his shares (converted to assets) balance
        // it should increase the underlying balance of the owner
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by the withdraw amount
        // it should decrease the balance of shares of the receiver by the withdraw amount converted in shares
        // it should return the same value as the one returned by previewWithdraw
        // it should return the same value as the burned (to the owner) shares amount
        // it should decrease the total supply of shares by the value returned by previewWithdraw
        // it should take the shares amount returned by previewWithdraw to the owner
    }

    function test_WhenWithdrawGivenVaultOpenGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenWithdrawGivenVaultClosedGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenWithdrawGivenReceiverIsAddress0() external {
        // it should revert with ERC20InvalidReceiver
    }
}
