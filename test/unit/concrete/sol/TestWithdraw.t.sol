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
                1
            )
        );
    }

    function test_WhenWithdrawPass() external {
        usersDealApproveAndDeposit(1);
        assertWithdraw(vaultUSDC, user1.addr, user1.addr, user1.addr, 1);
    }

    function test_GivenReceiverNotEqualOwnerWhenWithdraw() external {
        // it should pass withdraw assert
        usersDealApproveAndDeposit(1);
        assertWithdraw(vaultUSDC, user1.addr, user1.addr, user1.addr, 1);
    }

    function test_GivenWithdrawAmountIs0WhenWithdraw() external {
        // it should pass withdraw assert
        usersDealApproveAndDeposit(1);
        assertWithdraw(vaultUSDC, user1.addr, user1.addr, user1.addr, 0);
    }

    function test_GivenSenderNotOwnerAndAllowanceOfSenderForOwnerIsHigherThanWithdrawAmountWhenWithdraw(
    )
        external
    {
        // it should pass withdraw assert
        usersDealApproveAndDeposit(2);
        uint256 shares = vaultUSDC.previewWithdraw(1);
        vm.startPrank(user2.addr);
        vaultUSDC.approve(user1.addr, shares);
        vm.stopPrank();
        assertWithdraw(vaultUSDC, user1.addr, user2.addr, user1.addr, 1);
    }
}
