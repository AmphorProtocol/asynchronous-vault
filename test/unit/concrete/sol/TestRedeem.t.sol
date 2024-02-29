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

contract TestRedeem is TestBase {
    function test_GivenVaultClosedWhenRedeem() external {
        // it should revert with ERC4626ExceededMaxRedeem
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        redeemRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_RevertGiven_VaultIsEmptyAndAssetsIsHigherThan0WhenRedeem()
        external
    {
        // it should revert
        redeemRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenVaultPausedWhenRedeem() external {
        // it should revert with EnforcedPause
        pause(vaultUSDC);
        redeemRevert(
            vaultUSDC, user1, 1, PausableUpgradeable.EnforcedPause.selector
        );
    }

    function test_GivenVaultClosedGivenVaultNotPausedWhenRedeem() external {
        // it should revert with ERC4626ExceededMaxRedeem
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        redeemRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenReceiverIsAddress0WhenRedeem() external {
        // it should revert with ERC20InvalidReceiver
        usersDealApproveAndDeposit(1);
        redeemRevert(
            vaultUSDC,
            address0,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxRedeem.selector, 0x0, 1, 0
            )
        );
    }

    function test_GivenAssetsIsHigherThanOwnerSharesBalanceConvertedToAssetsWhenRedeem(
    )
        external
    {
        // it should revert with ERC4626ExceededMaxRedeem
        usersDealApproveAndDeposit(1);
        redeemRevert(
            vaultUSDC,
            user1,
            vaultUSDC.convertToAssets(vaultUSDC.balanceOf(user1.addr)) + 1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                vaultUSDC.convertToAssets(vaultUSDC.balanceOf(user1.addr)) + 1,
                vaultUSDC.convertToAssets(vaultUSDC.balanceOf(user1.addr))
            )
        );
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsLowerThanRedeemAmountWhenRedeem(
    )
        external
    {
        // it should revert with ERC20InsufficientAllowance
        usersDealApproveAndDeposit(1);

        redeemRevert(
            vaultUSDC,
            user1,
            user2,
            1,
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                user2.addr,
                0,
                1
            )
        );
    }

    function test_WhenRedeemPass() external {
        usersDealApproveAndDeposit(1);
        assertRedeem(vaultUSDC, user1.addr, user1.addr, user1.addr, 1);
    }

    function test_GivenReceiverNotEqualOwnerWhenRedeem() external {
        // it should pass redeem assert
        usersDealApproveAndDeposit(1);
        assertRedeem(vaultUSDC, user1.addr, user1.addr, user1.addr, 1);
    }

    function test_GivenRedeemAmountIs0WhenRedeem() external {
        // it should pass redeem assert
        usersDealApproveAndDeposit(1);
        assertRedeem(vaultUSDC, user1.addr, user1.addr, user1.addr, 0);
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsHigherThanRedeemAmountWhenRedeem(
    )
        external
    {
        // it should pass redeem assert
        usersDealApproveAndDeposit(2);
        uint256 shares = vaultUSDC.previewRedeem(1);
        vm.startPrank(user2.addr);
        vaultUSDC.approve(user1.addr, shares);
        vm.stopPrank();
        assertRedeem(vaultUSDC, user1.addr, user2.addr, user1.addr, 1);
    }
}
