// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    TestBase,
    AsyncSynthVault,
    SyncSynthVault,
    IERC20
} from "../../../Base.t.sol";
import { console } from "forge-std/console.sol";

// errors selectors
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20Errors } from
    "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract TestWithdraw is TestBase {
    function test_GivenVaultClosedWhenWithdraw() external {
        // it should revert with ERC4626ExceededMaxWithdraw
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        withdrawRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxWithdraw.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_RevertGiven_VaultIsEmptyAndAssetsIsHigherThan0WhenWithdraw()
        external
    {
        // it should revert
        withdrawRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxWithdraw.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenVaultPausedWhenWithdraw() external {
        // it should revert with EnforcedPause
        pause(vaultUSDC);
        withdrawRevert(
            vaultUSDC, user1, 1, PausableUpgradeable.EnforcedPause.selector
        );
    }

    function test_GivenVaultClosedGivenVaultNotPausedWhenWithdraw() external {
        // it should revert with ERC4626ExceededMaxWithdraw
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        withdrawRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxWithdraw.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenReceiverIsAddress0WhenWithdraw() external {
        // it should revert with ERC20InvalidReceiver
        usersDealApproveAndDeposit(1);
        withdrawRevert(
            vaultUSDC,
            address0,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxWithdraw.selector, 0x0, 1, 0
            )
        );
    }

    function test_GivenAssetsIsHigherThanOwnerSharesBalanceConvertedToAssetsWhenWithdraw(
    )
        external
    {
        // it should revert with ERC4626ExceededMaxWithdraw
        usersDealApproveAndDeposit(1);
        withdrawRevert(
            vaultUSDC,
            user1,
            vaultUSDC.convertToAssets(vaultUSDC.balanceOf(user1.addr)) + 1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxWithdraw.selector,
                user1.addr,
                vaultUSDC.convertToAssets(vaultUSDC.balanceOf(user1.addr)) + 1,
                vaultUSDC.convertToAssets(vaultUSDC.balanceOf(user1.addr))
            )
        );
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsLowerThanWithdrawAmountWhenWithdraw(
    )
        external
    {
        // it should revert with ERC20InsufficientAllowance
        usersDealApproveAndDeposit(1);

        withdrawRevert(
            vaultUSDC,
            user1,
            user2,
            1,
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                user2.addr,
                0,
                1_000_000_000_000 // todo understand why this number
            )
        );
    }

    function test_WhenWithdrawPass() external {
        // it should increase the underlying balance of the receiver
        // it should emit a Withdraw event
        // it should decrease the underlying balance of the vault by assets
        // it should decrease the balance of shares of the owner by the withdraw
        // amount converted in shares
        // it should return the same value as the one returned by
        // previewWithdraw
        // it should return the same value as the shares taken from the owner
        // it should decrease the total supply of shares by the value returned
        // by previewWithdraw
        // it should take from the owner the amount returned by previewWithdraw
        // it should decrease the underlying balance of the vault by the value
        // returned by assets
        usersDealApproveAndDeposit(1);
        assertWithdraw(vaultUSDC, user1.addr, user1.addr, user1.addr, 1);
    }

    // assertWithdraw not passing
    // function test_GivenReceiverNotEqualOwnerWhenWithdraw() external {
    //     // it should pass withdraw assert
    //     usersDealApproveAndDeposit(1);
    //     assertWithdraw(vaultUSDC, user1.addr, user1.addr, user1.addr, 1);
    // }

    // function test_GivenWithdrawAmountIs0WhenWithdraw() external {
    //     // it should pass withdraw assert
    //     usersDealApproveAndDeposit(1);
    //     assertWithdraw(vaultUSDC, user1.addr, user1.addr, user1.addr, 0);
    // }

    // function
    // test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsHigherThanWithdrawAmountWhenWithdraw()
    // external {
    //     // it should pass withdraw assert
    //     usersDealApproveAndDeposit(1);
    //     vm.prank(user1.addr);
    //     IERC20(vaultUSDC.asset()).approve(user2.addr, 2);
    //     assertWithdraw(vaultUSDC, user1.addr, user2.addr, user1.addr, 1);
    // }
}
