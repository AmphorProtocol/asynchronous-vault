// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestMint {
    function test_GivenVaultClosedWhenMint() external {
        // it should revert with ERC4626ExceededMaxMint
    }

    function test_GivenRequiredAssetsHigherThanOwnerAllowanceToTheVaultWhenDeposit() external {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_GivenRequiredAssetsHigherThanOwnerBalanceWhenDeposit() external {
        // it should revert with ERC20InsufficientBalance
    }

    function test_GivenVaultPausedWhenMint() external {
        // it should revert with EnforcedPause
    }

    function test_GivenVaultClosedGivenVaultNotPausedWhenMint() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_GivenReceiverIsAddress0WhenMint() external {
        // it should revert with ERC20InvalidReceiver
    }

    function test_GivenAmountIs0WhenMint() external {
        // it should revert with ERC20ZeroAmount (maybe)
    }

    function test_GivenPreviewMintIsHigherThanTheAllowanceOfTheOwnerToTheVaultWhenMint() external {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_GivenRequestedAmountOfSharesConvertedInAssetIsHigherThanTheBalanceOfTheOwnerWhenMint() external {
        // it should revert with ERC20InsufficientBalance
    }

    function test_GivenVaultOpenWhenMint() external {
        // it should decrease the underlying balance of the owner by convertToAsset(shares)
        // it should emit a Deposit event
        // it should emit TransferEvent of asset from the owner to the vault
        // it should emit TransferEvent of shares from the vault to the receiver
        // it should increase the underlying balance of the vault by convertToAsset(shares)
        // it should increase the balance of shares of the receiver by convertToAsset(shares)
        // it should return the same value as the one returned by previewMint
        // it should return the same value as the assets taken from the owner
        // it should increase the totalsupply by the specified shares
        // it should decrease the underlying balance of the owner by the amount returned by previewMint to the owner
    }

    function test_GivenReceiverNotEqualOwnerWhenMint() external {
        // it should pass like above
    }

    function test_GivenVaultEmptyWhenMint() external {
        // it should pass like above
    }

    function test_GivenDepositAmountIs0WhenMint() external {
        // it should pass like above
    }
}
