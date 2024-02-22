// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, IERC20 } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TestDecreaseDepositRequest is TestBase {
    function test_GivenVaultOpenWhenDecreaseDepositRequest() external {
        // it should revert with `VaultOpen`
        vm.expectRevert(SyncSynthVault.VaultIsOpen.selector);
        decreaseDepositRequest(vaultUSDC, user1, 1);
    }

    function test_GivenVaultClosedAndPausedWhenDecreaseDepositRequest() external {
        // it should revert with `EnforcedPause`
        usersDealApproveAndDeposit(1);
        close(vaultUSDC);
        vm.prank(vaultUSDC.owner());
        vaultUSDC.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        decreaseDepositRequest(vaultUSDC, user1, 1);
    }

    function test_GivenVaultStateOkAndAssetsTooHighWhenDecreaseDepositRequest() external {
        // it should revert if assets is higher than the owner deposit request balance
        usersDealApproveAndDeposit(1);
        close(vaultUSDC);
        uint256 userBalance = IERC20(vaultUSDC.asset()).balanceOf(user1.addr);
        vm.expectRevert();
        decreaseDepositRequest(vaultUSDC, user1, userBalance + 1);
    }

    function test_GivenVaultStateOkAndReceiverIsNotOwnerWhenDecreaseDepositRequest() external {
        usersDealApproveAndDeposit(1);
        close(vaultUSDC);
        assertDecreaseDeposit(vaultUSDC, user2.addr);
    }

    function test_GivenVaultStateOkAndReceiverIsOwnerWhenDecreaseDepositRequest() external {
        // it should pass same as above
        usersDealApproveAndDeposit(1);
        close(vaultUSDC);
        assertDecreaseDeposit(vaultUSDC, user1.addr);
    }
}
