// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    TestBase,
    AsyncVault,
    SyncVault,
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
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        redeemRevert(
            vaultTested,
            user1,
            1,
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxRedeem.selector,
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
            vaultTested,
            user1,
            1,
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenVaultPausedWhenRedeem() external {
        // it should revert with EnforcedPause
        pause(vaultTested);
        redeemRevert(
            vaultTested, user1, 1, PausableUpgradeable.EnforcedPause.selector
        );
    }

    function test_GivenVaultClosedGivenVaultNotPausedWhenRedeem() external {
        // it should revert with ERC4626ExceededMaxRedeem
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        redeemRevert(
            vaultTested,
            user1,
            1,
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenReceiverIsAddress0WhenRedeem() external {
        // it should revert with ERC20InvalidReceiver
        usersDealApproveAndDeposit(vaultTested, 1);
        redeemRevert(
            vaultTested,
            address0,
            1,
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxRedeem.selector, 0x0, 1, 0
            )
        );
    }

    function test_GivenAssetsIsHigherThanOwnerSharesBalanceConvertedToAssetsWhenRedeem(
    )
        external
    {
        // it should revert with ERC4626ExceededMaxRedeem
        usersDealApproveAndDeposit(vaultTested, 1);
        redeemRevert(
            vaultTested,
            user1,
            vaultTested.convertToAssets(vaultTested.balanceOf(user1.addr)) + 1,
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxRedeem.selector,
                user1.addr,
                vaultTested.convertToAssets(vaultTested.balanceOf(user1.addr))
                    + 1,
                vaultTested.convertToAssets(vaultTested.balanceOf(user1.addr))
            )
        );
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsLowerThanRedeemAmountWhenRedeem(
    )
        external
    {
        // it should revert with ERC20InsufficientAllowance
        usersDealApproveAndDeposit(vaultTested, 1);

        redeemRevert(
            vaultTested,
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
        usersDealApproveAndDeposit(vaultTested, 1);
        assertRedeem(vaultTested, user1.addr, user1.addr, user1.addr, 1);
    }

    function test_GivenReceiverNotEqualOwnerWhenRedeem() external {
        // it should pass redeem assert
        usersDealApproveAndDeposit(vaultTested, 1);
        assertRedeem(vaultTested, user1.addr, user1.addr, user1.addr, 1);
    }

    function test_GivenRedeemAmountIs0WhenRedeem() external {
        // it should pass redeem assert
        usersDealApproveAndDeposit(vaultTested, 1);
        assertRedeem(vaultTested, user1.addr, user1.addr, user1.addr, 0);
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsHigherThanRedeemAmountWhenRedeem(
    )
        external
    {
        // it should pass redeem assert
        usersDealApproveAndDeposit(vaultTested, 2);
        uint256 shares = vaultTested.previewRedeem(1);
        vm.startPrank(user2.addr);
        vaultTested.approve(user1.addr, shares);
        vm.stopPrank();
        assertRedeem(vaultTested, user1.addr, user2.addr, user1.addr, 1);
    }
}
