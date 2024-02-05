// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestMint {
    function test_WhenMintGivenVaultClosed() external {
        // it should revert with ERC4626ExceededMaxMint
    }

    function test_WhenMintGivenVaultOpen() external {
        // it should revert if the requested amount of shares converted in asset is higher than the allowance of the owner to the vault
        // it should revert if the requested amount of shares converted in asset is higher than the shares balance of the owner
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the one returned by previewMint
        // it should return the same value as the taken (to the owner) underlying amount
        // it should increase the total supply of shares
        // it should take the underlying amount returned by previewMint to the owner
    }

    function test_WhenMintGivenReceiverNotEqualOwner() external {
        // it should revert if the requested amount of shares converted in asset is higher than the allowance of the owner to the vault
        // it should revert if the requested amount of shares converted in asset is higher than the shares balance of the owner
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the one returned by previewMint
        // it should return the same value as the taken (to the owner) underlying amount
        // it should increase the total supply of shares
        // it should take the underlying amount returned by previewMint to the owner
    }

    function test_WhenMintGivenVaultEmpty() external {
        // it should revert if the requested amount of shares converted in asset is higher than the allowance of the owner to the vault
        // it should revert if the requested amount of shares converted in asset is higher than the shares balance of the owner
        // it should decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should increase the underlying balance of the vault
        // it should increase the balance of shares of the receiver
        // it should return the same value as the one returned by previewMint
        // it should return the same value as the taken (to the owner) underlying amount
        // it should increase the total supply of shares
        // it should take the underlying amount returned by previewMint to the owner
    }

    function test_WhenMintGivenDepositAmountIs0() external {
        // it should revert if the requested amount of shares converted in asset is higher than the allowance of the owner to the vault
        // it should revert if the requested amount of shares converted in asset is higher than the shares balance of the owner
        // it should nor increase and decrease the underlying balance of the owner
        // it should emit a Deposit event
        // it should nor increase and decrease the underlying balance of the vault
        // it should nor increase and decrease the balance of shares of the receiver
        // it should return the same value as the one returned by previewMint
        // it should return the same value as the taken (to the owner) underlying amount
        // it should nor increase and decrease the total supply of shares
        // it should take the underlying amount returned by previewMint to the owner
    }

    function test_WhenMintGivenVaultOpenGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenMintGivenVaultClosedGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenMintGivenReceiverIsAddress0() external {
        // it should revert with ERC20InvalidReceiver
    }
}
