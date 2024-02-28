// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { SyncSynthVault } from "../../../../src/SyncSynthVault.sol";
import "forge-std/console.sol"; //todo remove

contract TestOpen is TestBase {
    function test_GivenVaultIsOpenWhenOpen() external {
        // it should revert with VaultIsOpen

        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        vaultUSDC.open(uint256(0));
    }

    function test_GivenMsgSenderIsNotOwnerWhenOpen() external {
        // it should revert with OwnableUnauthorizedAccount(msg.sender)
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        vaultUSDC.open(uint256(0));
    }

    function test_GivenAssetReturnedIs0AndTotalsAssetsIsNot0AndMaxDrawdownIsNot0WhenOpen() external {
        // it should revert with MaxDrawdownReached
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.startPrank(owner);
        vaultUSDC.close();
        vm.expectRevert(SyncSynthVault.MaxDrawdownReached.selector);
        vaultUSDC.open(uint256(0));
    }

    function test_GivenAssetReturnedIs1AndTotalsAssetsIsOverAssetsReturnedAndMaxDrawdownIsNot0WhenOpen() external {
        // it should revert with MaxDrawdownReached
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.startPrank(owner);
        vaultUSDC.close();
        vm.expectRevert(SyncSynthVault.MaxDrawdownReached.selector);
        vaultUSDC.open(uint256(1));
    }

    function test_WhenOpenSucceed() external {
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();
        assertOpen(vaultUSDC, 0);
    }

    function test_GivenPeriodIsInProfitWhenOpen() external {
        usersDealApproveAndDeposit(3);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();
        assertOpen(vaultUSDC, 4);
    }

    function test_GivenPeriodIsInLossWhenOpen() external {
        usersDealApproveAndDeposit(2);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();
        assertOpen(vaultUSDC, -3);
    }

    function test_GivenPeriodIsInProfitAndRequestDepWhenOpen() external {
        usersDealApproveAndDeposit(2);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();

        usersDealApproveAndRequestDeposit(vaultUSDC, 2, "");
        assertOpen(vaultUSDC, 3);
    }

    function test_GivenPeriodIsInProfitAndRequestsWhenOpen() external {
        usersDealApproveAndDeposit(2);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();

        usersDealApproveAndRequestDeposit(vaultUSDC, 2, "");
        usersDealApproveAndRequestRedeem(vaultUSDC, 2, "");
        assertOpen(vaultUSDC, 3);
    }
}
