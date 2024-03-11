// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { SyncSynthVault } from "../../../../src/SyncSynthVault.sol";
import "forge-std/console.sol"; //todo remove

contract TestClose is TestBase {
    function test_GivenVaultIsClosedWhenClose() external {
        // it should revert with VaultIsOpen
        usersDealApproveAndDeposit(vaultTested, 1);
        address owner = vaultTested.owner();
        vm.startPrank(owner);
        vaultTested.close();
        vm.expectRevert(SyncSynthVault.VaultIsClosed.selector);
        vaultTested.close();
        vm.stopPrank();
    }

    function test_GivenMsgSenderIsNotOwnerWhenClose() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", address(this)
            )
        );
        vaultTested.close();
    }

    function test_GivenTotalAssetIs0WhenClose() external {
        // it should revert with MaxDrawdownReached
        address owner = vaultTested.owner();
        vm.startPrank(owner);
        vm.expectRevert(SyncSynthVault.VaultIsEmpty.selector);
        vaultTested.close();
        vm.stopPrank();
    }

    function test_WhenCloseSucceed() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
    }
}
