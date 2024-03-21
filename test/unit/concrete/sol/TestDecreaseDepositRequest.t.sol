// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, IERC20 } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TestDecreaseDepositRequest is TestBase {
    function test_GivenVaultOpenWhenDecreaseDepositRequest() external {
        // it should revert with `VaultOpen`
        vm.expectRevert(SyncVault.VaultIsOpen.selector);
        decreaseDepositRequest(vaultTested, user1, 1);
    }

    function test_GivenVaultClosedAndPausedWhenDecreaseDepositRequest()
        external
    {
        // it should revert with `EnforcedPause`
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        vm.prank(vaultTested.owner());
        vaultTested.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        decreaseDepositRequest(vaultTested, user1, 1);
    }

    function test_GivenVaultStateOkAndAssetsTooHighWhenDecreaseDepositRequest()
        external
    {
        // it should revert if assets is higher than the owner deposit request
        // balance
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        uint256 userBalance = IERC20(vaultTested.asset()).balanceOf(user1.addr);
        vm.expectRevert();
        decreaseDepositRequest(vaultTested, user1, userBalance + 1);
    }

    function test_GivenVaultStateOkAndReceiverIsNotOwnerWhenDecreaseDepositRequest(
    )
        external
    {
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        assertDecreaseDeposit(vaultTested, user2.addr);
    }

    function test_GivenVaultStateOkAndReceiverIsOwnerWhenDecreaseDepositRequest(
    )
        external
    {
        // it should pass same as above
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);
        assertDecreaseDeposit(vaultTested, user1.addr);
    }
}
