// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestDecreaseDepositRequest {
    function test_GivenVaultOpenWhenDecreaseDepositRequest() external {
        // it should revert with `VaultOpen`
    }

    function test_GivenVaultClosedAndPausedWhenDecreaseDepositRequest() external {
        // it should revert with `EnforcedPause`
    }

    function test_GivenVaultStateOkAndAssetsTooHighWhenDecreaseDepositRequest() external {
        // it should revert if assets is higher than the owner deposit request balance
    }

    function test_GivenVaultStateOkAndReceiverIsNotOwnerWhenDecreaseDepositRequest() external {
        // it should decrease of assets the deposit request balance of owner
        // it should decrease of assets the vault underlying balance
        // it should increase of assets the receiver underlying balance
        // it should emit `DepositRequestDecreased` event
    }

    function test_GivenVaultStateOkAndReceiverIsOwnerWhenDecreaseDepositRequest() external {
        // it should pass same as above
    }
}
