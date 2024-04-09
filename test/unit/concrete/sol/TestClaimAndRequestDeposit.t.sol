// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, IERC20 } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TestClaimAndRequestDeposit is TestBase {
    function test_WhenClaimAndRequestDeposit() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        usersDealApproveAndRequestDeposit(vaultTested, 1);
        assertOpen(vaultTested, 0);
        //vm.expectRevert(SyncVault.VaultIsOpen.selector);
        //decreaseDepositRequest(vaultTested, user1, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 pendingDepositBefore =
            vaultTested.pendingDepositRequest(user1.addr);
        vm.prank(user1.addr);
        vaultTested.requestDeposit(10 ** 18, user1.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 pendingDepositAfter =
            vaultTested.pendingDepositRequest(user1.addr);
        assertLt(
            sharesBefore, sharesAfter, "Shares of receiver should increase"
        );
        assertLt(
            pendingDepositBefore,
            pendingDepositAfter,
            "Pending deposit of msg.sender should increase"
        );
    }

    function test_WhenClaimAndRequestRedeemWhenNothingToClaim() external {
        usersDealApproveAndDeposit(vaultTested, 1);
        assertClose(vaultTested);
        uint256 sharesBefore = vaultTested.balanceOf(user1.addr);
        uint256 assetsBefore = underlying.balanceOf(user1.addr);
        uint256 pendingDepositBefore =
            vaultTested.pendingDepositRequest(user1.addr);
        vm.prank(user1.addr);
        vaultTested.requestDeposit(10 ** 18, user1.addr, user1.addr, "");

        uint256 sharesAfter = vaultTested.balanceOf(user1.addr);
        uint256 assetsAfter = underlying.balanceOf(user1.addr);
        uint256 pendingDepositAfter =
            vaultTested.pendingDepositRequest(user1.addr);
        assertEq(
            sharesBefore, sharesAfter, "Shares of receiver should stay the same"
        );
        assertGt(
            assetsBefore, assetsAfter, "Assets of receiver should decrease"
        );

        assertLt(
            pendingDepositBefore,
            pendingDepositAfter,
            "Pending deposit of msg.sender should increase"
        );
    }
}
