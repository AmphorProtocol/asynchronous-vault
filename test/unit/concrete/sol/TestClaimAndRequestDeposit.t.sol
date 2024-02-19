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
        decreaseDepositPass(user2.addr);
    }

    function test_GivenVaultStateOkAndReceiverIsOwnerWhenDecreaseDepositRequest() external {
        // it should pass same as above
        decreaseDepositPass(user1.addr);
    }

    function decreaseDepositPass(address receiver) internal {
        // it should decrease of assets the deposit request balance of owner
        // it should decrease of assets the vault underlying balance
        // it should increase of assets the receiver underlying balance
        // it should emit `DepositRequestDecreased` event -> todo

        usersDealApproveAndDeposit(1);
        close(vaultUSDC);
        
        uint256 ownerDepRequestBalance = vaultUSDC.pendingDepositRequest(user1.addr);
        uint256 ownerDecreaseAmount = ownerDepRequestBalance/2;
        uint256 finalOwnerDepRequestBalance = ownerDepRequestBalance - ownerDecreaseAmount;
        uint256 vaultUnderlyingBalanceBef = IERC20(vaultUSDC.asset()).balanceOf(address(vaultUSDC));
        uint256 user2UnderlyingBalanceBef = IERC20(vaultUSDC.asset()).balanceOf(receiver);
        decreaseRedeemRequest(vaultUSDC, user1, user2, ownerDecreaseAmount);
        assertEq(vaultUSDC.pendingDepositRequest(user1.addr), finalOwnerDepRequestBalance);
        assertEq(IERC20(vaultUSDC.asset()).balanceOf(address(vaultUSDC)), vaultUnderlyingBalanceBef - ownerDecreaseAmount);
        assertEq(IERC20(vaultUSDC.asset()).balanceOf(receiver), user2UnderlyingBalanceBef + ownerDecreaseAmount);
    }
}
