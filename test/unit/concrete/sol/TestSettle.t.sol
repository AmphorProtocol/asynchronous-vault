
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, AsyncSynthVault } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestSettle is TestBase {
    function test_RevertGiven_SenderNotOwner() external {
        // it should revert
    }

    function test_RevertGiven_VaultIsPaused() external {
        // it should revert
    }

    function test_RevertGiven_VaultIsOpen() external {
        // it should revert
    }

    function test_RevertGiven_NewSavedBalanceIs0() external {
        // it should revert
    }

    function test_RevertGiven_NewSavedBalanceIsGreaterThan0ButMoreThan3000BipsLessThanTheCurrentSavedBalance()
        external
    {
        // it should revert
    }

    function test_GivenNewSavedBalanceIsGreaterThan0But1000BipsLessThanLastSavedBalance() external {
        // it should pass assertSettle
    }

    function test_GivenNewSavedBalanceIsGreaterThan0But1000BipsMoreThanLastSavedBalance() external {
        // it should pass assertSettle
    }

    function test_GivenNewSavedBalanceIsGreaterThan0ButMoreThan3000BipsMoreThanTheCurrentSavedBalance() external {
        // it should pass assertSettle
    }

    function test_WhenAssertSettle() external {
        // it should not revert
        // it take 20% fees on the performance and emits an event about it (EpochEnd)
        // it should show the new lastSavedBalance with performance fees taken in account (EpochEnd)
        // it should process the redeem and deposit requests (checkable thx to totalSupply, newSavedBalance and fees)
        // it should update the lastSavedBalance (lastSavedBalance = lastSavedBalance + pendingDeposit - pendingToWithdraw)
        // it should transfer (pendingWithdraw - pendingDeposit) underlying from owner to the vault (claimable silo) if pendingWithdraw is higher than pendingDeposit
        // it should transfer (pendingDeposit - pendingWithdraw) underlying from vault to the owner (claimable silo) if pendingDeposit is higher than pendingWithdraw
        // it should not open the vault
        // it should emit Deposit
        // it should emit Withdraw
        // it should emit AsyncDeposit
        // it should emit AsyncWithdraw
    }
}

