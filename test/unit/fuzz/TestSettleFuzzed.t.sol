// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, AsyncVault } from "../../Base.t.sol";
import "forge-std/console.sol";

contract TestSettleFuzzed is TestBase {
    function setUp() external {
        // vault should not be empty
        usersDealApproveAndDeposit(vaultTested, 3);
    }

    // function test_RevertGiven_SenderNotOwner() external {
    //     // it should revert
    //     close(vaultTested);
    //     uint256 lastSavedBalance = vaultTested.lastSavedBalance();
    //     vm.startPrank(user1.addr);
    //     vm.expectRevert(); // not owner
    //     vaultTested.settle(lastSavedBalance);
    // }

    // function test_RevertGiven_VaultIsPaused() external {
    //     // it should revert
    //     close(vaultTested);
    //     uint256 lastSavedBalance = vaultTested.lastSavedBalance();
    //     pause(vaultTested);
    //     vm.startPrank(vaultTested.owner());
    //     vm.expectRevert(); // vault paused
    //     vaultTested.settle(lastSavedBalance);
    // }

    // function test_RevertGiven_VaultIsOpen() external {
    //     // it should revert
    //     uint256 lastSavedBalance = vaultTested.lastSavedBalance();
    //     vm.startPrank(vaultTested.owner());
    //     vm.expectRevert(); // vault paused
    //     vaultTested.settle(lastSavedBalance);
    // }

    // function test_RevertGiven_NewSavedBalanceIs0() external {
    //     // it should revert
    //     close(vaultTested);
    //     vm.startPrank(vaultTested.owner());
    //     vm.expectRevert(); // not owner
    //     vaultTested.settle(0);
    // }

    // function
    // test_RevertGiven_NewSavedBalanceIsGreaterThan0ButMoreThan3000BipsLessThanTheCurrentSavedBalance()
    //     external
    // {
    //     // it should revert
    //     close(vaultTested);
    //     uint256 lastSavedBalance = vaultTested.lastSavedBalance();
    //     vm.startPrank(vaultTested.owner());
    //     vm.expectRevert(); // not owner
    //     vaultTested.settle(lastSavedBalance / 2);
    // }

    // function
    // test_GivenNewSavedBalanceIsGreaterThan0But1000BipsLessThanLastSavedBalance()
    // external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     assertSettle(vaultTested, -1000);
    // }

    // function
    // test_GivenNewSavedBalanceIsGreaterThan0But1000BipsMoreThanLastSavedBalance()
    // external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     assertSettle(vaultTested, 1000);

    // }

    // function
    // test_GivenNewSavedBalanceIsGreaterThan0ButMoreThan3000BipsMoreThanTheCurrentSavedBalance()
    // external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     assertSettle(vaultTested, 3001);
    // }

    // function test_GivenPerfIs0Bip() external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     assertSettle(vaultTested, 0);
    // }

    // function test_GivenPerfIs1000Bip() external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     assertSettle(vaultTested, 1000);
    // }

    // function test_GivenOnlyAsyncRedeemsAreNull() external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     usersDealApproveAndRequestDeposit(vaultTested, 3);
    //     assertSettle(vaultTested, 0);
    // }

    // function test_GivenOnlyAsyncDepositsAreNull() external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     usersDealApproveAndRequestRedeem(vaultTested, 1);
    //     assertSettle(vaultTested, 0);
    // }

    // function test_GivenAsyncRedeemsAndDepositsAreEqual() external {
    //     // it should pass assertSettle
    //     close(vaultTested);
    //     usersDealApproveAndRequestDeposit(vaultTested, 3);
    //     usersDealApproveAndRequestRedeem(vaultTested, 3);
    //     assertSettle(vaultTested, 0);
    // }

    function test_GivenRandomValuesWhenSettle(
        uint256 depositAmount,
        uint256 redeemAmount,
        int256 performanceInBips
    )
        external
    {
        vm.assume(depositAmount < 1 * 10 ** 6);
        vm.assume(redeemAmount < vaultTested.balanceOf(user2.addr));
        vm.assume(performanceInBips > -3000 && performanceInBips < 10_000);
        close(vaultTested);
        usersDealApprove(vaultTested, 2);
        console.log("depositAmount", depositAmount);
        console.log("assetBalance", vaultTested.balanceOf(user1.addr));
        vm.prank(user1.addr);
        vaultTested.requestDeposit(depositAmount, user1.addr, user1.addr, "");
        vm.prank(user2.addr);
        vaultTested.requestRedeem(redeemAmount, user2.addr, user2.addr, "");
        assertSettle(vaultTested, performanceInBips);
    }

    // function test_WhenAssertSettle() external {
    //     // it should not revert
    //     // it take 20% fees on the performance and emits an event about it
    // (EpochEnd)
    //     // it should show the new lastSavedBalance with performance fees
    // taken in account (EpochEnd)
    //     // it should process the redeem and deposit requests (checkable thx
    // to totalSupply, newSavedBalance and fees)
    //     // it should update the lastSavedBalance (lastSavedBalance =
    // lastSavedBalance + pendingDeposit - pendingToWithdraw)
    //     // it should transfer (pendingWithdraw - pendingDeposit) underlying
    // from owner to the vault (claimable silo) if pendingWithdraw is higher
    // than pendingDeposit
    //     // it should transfer (pendingDeposit - pendingWithdraw) underlying
    // from vault to the owner (claimable silo) if pendingDeposit is higher than
    // pendingWithdraw
    //     // it should not open the vault
    //     // it should emit Deposit
    //     // it should emit Withdraw
    //     // it should emit AsyncDeposit
    //     // it should emit AsyncWithdraw
    // }
}
