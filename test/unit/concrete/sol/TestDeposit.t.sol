// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestDeposit {
    function test_GivenVaultClosedWhenDeposit() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_GivenAmountHigherThanOwnerAllowanceToTheVaultWhenDeposit() external {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_GivenAmountHigherThanOwnerBalanceWhenDeposit() external {
        // it should revert with ERC20InsufficientBalance
    }

    function test_GivenVaultOpenGivenVaultPausedWhenDeposit() external {
        // it should revert with EnforcedPause
    }

    function test_GivenVaultClosedGivenPausedWhenDeposit() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_GivenReceiverIsAddress0WhenDeposit() external {
        // it should revert with ERC20InvalidReceiver
    }

    function test_GivenAmountIs0WhenDeposit() external {
        // it should revert with ERC20ZeroAmount (maybe)
    }

    function test_GivenAmountIsNWhenDeposit() external {
        // it should decrease underlying balance of the owner by n
        // it should emit a Deposit event
        // it should increase the balance of shares of the receiver by previewDeposit(assets) returned value
        // it should return the same value as the minted shares amount
        // it should return the same value as the increase of receiver shares balance
        // it should increase the total supply of shares by the previewDeposit(assetsAmount) returned value
        // it should return the same value as the one returned by previewDeposit(assets)
    }

    function test_GivenVaultOpenGivenReceiverNotEqualOwnerWhenDeposit() external {
        // it should pass the like as above
    }

    function test_GivenVaultOpenGivenVaultEmptyWhenDeposit() external {
        // it should pass the like as above
    }

    function test_GivenVaultOpenGivenDepositAmountEqual0WhenDeposit() external {
        // it should pass the like as above
    }
}
