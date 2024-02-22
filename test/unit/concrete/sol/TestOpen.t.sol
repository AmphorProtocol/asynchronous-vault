// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { SyncSynthVault } from "../../../../src/SyncSynthVault.sol";

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
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", address(this)
            )
        );
        vaultUSDC.open(uint256(0));
    }

    function test_GivenAssetReturnedIs0AndTotalsAssetsIsNot0AndMaxDrawdownIsNot0WhenOpen(
    )
        external
    {
        // it should revert with MaxDrawdownReached
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.startPrank(owner);
        vaultUSDC.close();
        vm.expectRevert(SyncSynthVault.MaxDrawdownReached.selector);
        vaultUSDC.open(uint256(0));
    }

    function test_GivenAssetReturnedIs1AndTotalsAssetsIsOverAssetsReturnedAndMaxDrawdownIsNot0WhenOpen(
    )
        external
    {
        // it should revert with MaxDrawdownReached
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.startPrank(owner);
        vaultUSDC.close();
        vm.expectRevert(SyncSynthVault.MaxDrawdownReached.selector);
        vaultUSDC.open(uint256(1));
    }

    function test_WhenOpenSucceed() external {
        // it should set the vault state to open
        // it should set the vault lastOpen to the current block timestamp
        // it should emit `VaultOpened` event
        usersDealApproveAndDeposit(1);
        address owner = vaultUSDC.owner();
        vm.prank(owner);
        vaultUSDC.close();
        assertOpen(vaultUSDC, 1);
    }

    function test_GivenPeriodIsInProfitWhenOpen() external {
        // it should transfer assetsReturned - ((totalAssets - assetReturned) *
        // fees / 10 000) from msg.sender to the vault
        // it should pass when open succeed
    }

    function test_GivenPeriodIsInLossWhenOpen() external {
        // it should transfer assetsReturned from msg.sender to the vault
        // it should pass when open succeed
    }
}
