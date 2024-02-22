// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestWithdraw {
    function test_GivenVaultClosedWhenWithdraw() external {
        // it should revert with ERC4626ExceededMaxWithdraw
    }

    function test_RevertGiven_VaultIsEmptyAndAssetsIsHigherThan0WhenWithdraw() external {
        // it should revert
    }

    function test_GivenVaultPausedWhenWithdraw() external {
        // it should revert with EnforcedPause
    }

    function test_GivenVaultClosedGivenVaultNotPausedWhenWithdraw() external {
        // it should revert with ERC4626ExceededMaxWithdraw
    }

    function test_GivenReceiverIsAddress0WhenWithdraw() external {
        // it should revert with ERC20InvalidReceiver
    }

    function test_GivenAssetsIsHigherThanOwnerSharesBalanceConvertedToAssetsWhenWithdraw() external {
        // it should revert with ERC4626ExceededMaxWithdraw
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsLowerThanWithdrawAmountWhenWithdraw() external {
        // it should revert with ERC20InsufficientAllowance
    }

    function test_WhenWithdrawPass() external {
        // it should increase the underlying balance of the receiver
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by assets
        // it should decrease the balance of shares of the owner by the withdraw amount converted in shares
        // it should return the same value as the one returned by previewWithdraw
        // it should return the same value as the shares taken from the owner
        // it should decrease the total supply of shares by the value returned by previewWithdraw
        // it should take from the owner the amount returned by previewWithdraw
        // it should decrease the underlying balance of the vault by the value returned by assets
    }

    function test_GivenReceiverNotEqualOwnerWhenWithdraw() external {
        // it should pass withdraw assert
    }

    function test_GivenWithdrawAmountIs0WhenWithdraw() external {
        // it should pass withdraw assert
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsHigherThanWithdrawAmountWhenWithdraw() external {
        // it should pass withdraw assert
    }
}
