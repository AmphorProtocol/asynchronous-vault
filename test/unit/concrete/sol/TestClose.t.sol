// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { SyncSynthVault } from "../../../../src/SyncSynthVault.sol";
import "forge-std/console.sol"; //todo remove

contract TestClose is TestBase {
    function test_GivenVaultIsClosedWhenClose() external {
        // it should revert with VaultIsOpen
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.startPrank(owner);
        vaultUSDC.close();
        vm.expectRevert(SyncSynthVault.VaultIsLocked.selector);
        vaultUSDC.close();
        vm.stopPrank();
    }

    function test_GivenMsgSenderIsNotOwnerWhenClose() external {
        usersDealApproveAndDeposit(1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", address(this)
            )
        );
        vaultUSDC.close();
    }

    function test_GivenTotalAssetIs0WhenClose() external {
        // it should revert with MaxDrawdownReached
        address owner = vaultUSDC.owner();
        vm.startPrank(owner);
        vm.expectRevert(SyncSynthVault.VaultIsEmpty.selector);
        vaultUSDC.close();
        vm.stopPrank();
    }

    function test_WhenCloseSucceed() external {
        usersDealApproveAndDeposit(1);
        assertClose(vaultUSDC);

    }
}
