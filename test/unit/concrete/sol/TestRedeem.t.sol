// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestRedeem {
    function test_RevertGiven_SharesProvidedIsHigherThanOwnerSharesBalanceWhenRedeem(
    )
        external
    {
        // it should revert
    }

    function test_GivenVaultClosedWhenRedeem() external {
        // it should revert with ERC4626ExceededMaxWithdraw
    }

    function test_GivenVaultPausedWhenRedeem() external {
        // it should revert with EnforcedPause
    }

    function test_GivenVaultClosedAndNotPausedWhenRedeem() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_GivenReceiverIsAddress0WhenRedeem() external {
        // it should revert with ERC20InvalidReceiver
    }

    function test_WhenRedeemPass() external {
        // it should increase the underlying balance of the receiver by
        // convertToAsset(shares)
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by
        // convertToAsset() of the shares
        // it should decrease the balance of shares of the owner by shares
        // it should return the same value as the one returned by previewRedeem
        // it should return the same value as the assets taken from the owner
        // it should decrease the total supply of shares by shares
        // it should take from the owner the amount returned by previewWithdraw
        // it should decrease the underlying balance of the vault by
        // convertToAsset(shares)
    }

    function test_GivenReceiverNotEqualOwnerWhenRedeem() external {
        // it should pass when redeem pass
    }

    function test_GivenDepositAmountIs0WhenRedeem() external {
        // it should pass when redeem pass
    }
}
