// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { SyncVault } from "../../../../src/SyncVault.sol";
import "forge-std/console.sol";

contract TestOpen is TestBase {
    function test_GivenVaultIsOpenWhenOpen() external {
        // it should revert with VaultIsOpen

        address owner = vaultTested.owner();
        vm.prank(owner);
        vm.expectRevert(SyncVault.VaultIsOpen.selector);
        vaultTested.open(uint256(0));
    }

    function test_GivenMsgSenderIsNotOwnerWhenOpen() external {
        // it should revert with OwnableUnauthorizedAccount(msg.sender)
        usersDealApproveAndDeposit(vaultTested, 1);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", address(this)
            )
        );
        vaultTested.open(uint256(0));
    }

    function test_GivenAssetReturnedIs0AndTotalsAssetsIsNot0AndMaxDrawdownIsNot0WhenOpen(
    )
        external
    {
        // it should revert with MaxDrawdownReached
        usersDealApproveAndDeposit(vaultTested, 1);
        address owner = vaultTested.owner();
        vm.startPrank(owner);
        vaultTested.close();
        vm.expectRevert(SyncVault.MaxDrawdownReached.selector);
        vaultTested.open(uint256(0));
    }

    function test_GivenAssetReturnedIs1AndTotalsAssetsIsOverAssetsReturnedAndMaxDrawdownIsNot0WhenOpen(
    )
        external
    {
        // it should revert with MaxDrawdownReached
        usersDealApproveAndDeposit(vaultTested, 1);
        address owner = vaultTested.owner();
        vm.startPrank(owner);
        vaultTested.close();
        vm.expectRevert(SyncVault.MaxDrawdownReached.selector);
        vaultTested.open(uint256(1));
    }

    function test_WhenOpenSucceed() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();
        assertOpen(vaultTested, 0);
    }

    function test_GivenPeriodIsInProfitWhenOpen() external {
        usersDealApproveAndDeposit(vaultTested, 3);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();
        assertOpen(vaultTested, 4);
    }

    function test_GivenPeriodIsInLossWhenOpen() external {
        usersDealApproveAndDeposit(vaultTested, 2);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();
        assertOpen(vaultTested, -3);
    }

    function test_GivenPeriodIsInProfitAndRequestDepWhenOpen() external {
        usersDealApproveAndDeposit(vaultTested, 2);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();

        usersDealApproveAndRequestDeposit(vaultTested, 2, "");
        assertOpen(vaultTested, 3);
    }

    function test_GivenPeriodIsInProfitAndRequestsWhenOpen() external {
        usersDealApproveAndDeposit(vaultTested, 2);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();

        usersDealApproveAndRequestDeposit(vaultTested, 2, "");
        usersDealApproveAndRequestRedeem(vaultTested, 2, "");
        assertOpen(vaultTested, 3);
    }

    function test_GivenMaxDrawdownIsReachedWhenOpen() external {
        usersDealApproveAndDeposit(vaultTested, 2);
        address owner = vaultTested.owner();
        vm.prank(owner);
        vaultTested.close();
        usersDealApproveAndRequestRedeem(vaultTested, 2, "");
        assertOpen(vaultTested, -3001, true);
    }
}
