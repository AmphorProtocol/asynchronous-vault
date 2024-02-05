// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestRedeem {
    function test_WhenRedeemGivenVaultOpen() external {
        // it should revert if the redeem amount provided by the owner is higher than his shares balance
        // it should increase the underlying balance of the owner by the value returned by convertToAsset() of the shares amount provided
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by the value returned by convertToAsset() of the shares amount provided
        // it should decrease the balance of shares of the receiver by the shares amount provided
        // it should decrease the total supply of shares by the shares amount provided
        // it should decrease the shares amount provided to the owner
        // it should return the same value as the one returned by previewRedeem
        // it should return the same value as the taken (to the owner) assets amount
    }

    function test_WhenRedeemGivenVaultOpenGivenReceiverNotEqualOwner() external {
        // it should revert if the redeem amount provided by the owner is higher than his shares balance
        // it should increase the underlying balance of the owner by the value returned by convertToAsset() of the shares amount provided
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by the value returned by convertToAsset() of the shares amount provided
        // it should decrease the balance of shares of the receiver by the shares amount provided
        // it should decrease the total supply of shares by the shares amount provided
        // it should decrease the shares amount provided to the owner
        // it should return the same value as the one returned by previewRedeem
        // it should return the same value as the taken (to the owner) assets amount
    }

    function test_WhenRedeemGivenVaultOpenGivenVaultEmpty() external {
        // it should revert if the withdraw amount provided by the owner is higher than 0
    }

    function test_WhenRedeemGivenVaultOpenGivenDepositAmountIs0() external {
        // it should revert if the redeem amount provided by the owner is higher than his shares balance
        // it should increase the underlying balance of the owner by the value returned by convertToAsset() of the shares amount provided
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by the value returned by convertToAsset() of the shares amount provided
        // it should decrease the balance of shares of the receiver by the shares amount provided
        // it should decrease the total supply of shares by the shares amount provided
        // it should decrease the shares amount provided to the owner
        // it should return the same value as the one returned by previewRedeem
        // it should return the same value as the taken (to the owner) assets amount
    }

    function test_WhenRedeemGivenVaultOpenGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenRedeemGivenVaultClosedGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenRedeemGivenVaultClosedGivenVaultNotPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenRedeemGivenReceiverIsAddress0() external {
        // it should revert with ERC20InvalidReceiver
    }
}
