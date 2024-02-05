// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../Base.t.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestDeposit is TestBase {
    function test_WhenDepositGivenVaultClosed() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    // function test_simpleDeposit() public { // to show case the  use
    //     usersDealApproveAndDeposit(5);
    //     uint256 userBalance = vaultAssetBalanceOf(vaultUSDC, user5.addr);
    //     assertDeposit(vaultUSDC, user4.addr, user8.addr, userBalance);
    // }

    // function test_simpleDeposit2() public {
    //     usersDealApproveAndDeposit(5);
    //     assertDeposit(vaultUSDC, user6.addr, user8.addr, 0);
    // }

    function test_WhenDepositGivenVaultOpen() external {
        //it should pass assertDeposit
    }

    function test_WhenDepositGivenVaultOpenGivenReceiverNotEqualOwner()
        external
    {
        // it should revert if the deposit amount is higher than the allowance
        // of the owner to the vault
        // it should revert if the deposit amount is higher than the balance of
        // the owner
        // it should decrease the underlying balance of the owner by the
        // specified assets amount input
        // it should emit a Deposit event
        // it should increase the balance of shares of the receiver by
        // previewDeposit(assetsAmount) returned value
        // it should return the same value as the minted shares amount
        // it should return the same value as the increase of receiver shares
        // balance
        // it should return the same value as the one returned by previewDeposit
        // it should increase the total supply of shares by the
        // previewDeposit(assetsAmount) returned value
    }

    function test_WhenDepositGivenVaultOpenGivenVaultEmpty() external {
        // it should revert if the deposit amount is higher than the allowance
        // of the owner to the vault
        // it should revert if the deposit amount is higher than the balance of
        // the owner
        // it should decrease the underlying balance of the owner by the
        // specified assets amount input
        // it should emit a Deposit event
        // it should increase the balance of shares of the receiver by
        // previewDeposit(assetsAmount) returned value
        // it should return the same value as the minted shares amount
        // it should return the same value as the increase of receiver shares
        // balance
        // it should return the same value as the one returned by previewDeposit
        // it should increase the total supply of shares by the
        // previewDeposit(assetsAmount) returned value
    }

    function test_WhenDepositGivenVaultOpenGivenDepositAmountEqual0()
        external
    {
        // it should revert if the deposit amount is higher than the allowance
        // of the owner to the vault
        // it should revert if the deposit amount is higher than the balance of
        // the owner
        // it should decrease the underlying balance of the owner by the
        // specified assets amount input
        // it should emit a Deposit event
        // it should increase the balance of shares of the receiver by
        // previewDeposit(assetsAmount) returned value
        // it should return the same value as the minted shares amount
        // it should return the same value as the increase of receiver shares
        // balance
        // it should return the same value as the one returned by previewDeposit
        // it should increase the total supply of shares by the
        // previewDeposit(assetsAmount) returned value
    }

    function test_WhenDepositGivenVaultOpenGivenVaultPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenDepositGivenVaultClosedGivenPaused() external {
        // it should revert with ERC4626ExceededMaxDeposit
    }

    function test_WhenDepositGivenReceiverIsAddress0() external {
        // it should revert with ERC20InvalidReceiver
    }
}
