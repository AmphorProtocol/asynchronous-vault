// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, IERC20Metadata } from "../../../Base.t.sol";

contract TestClaimDeposit is TestBase {
    // claim with nothing to claim
    function test_whenClaimDepWithNothingToClaim() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 1);
        usersDealApprove(vaultTested, 2);
        // assertClaimDeposit(vaultTested, user2.addr, user2.addr, 0); // revert -> NoClaimAvailable
    }

    // claim with something to claim
    function test_whenClaimDepWithSomethingToClaim() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 4);
        usersDealApprove(vaultTested, 10);
        assertClose(vaultTested);
        uint256 assets =
            IERC20Metadata(vaultTested.asset()).balanceOf(user5.addr);
        assertRequestDeposit(
            vaultTested, user5.addr, user5.addr, user5.addr, assets, ""
        );
        assertOpen(vaultTested, 3);
        assertClaimDeposit(vaultTested, user5.addr, user5.addr, assets);
    }

    function test_whenClaimDepWithSomethingToClaimAndVaultIsClosed() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 4);
        usersDealApprove(vaultTested, 5);
        assertClose(vaultTested);
        uint256 assets =
            IERC20Metadata(vaultTested.asset()).balanceOf(user5.addr);
        assertRequestDeposit(
            vaultTested, user5.addr, user5.addr, user5.addr, assets, ""
        );
        assertOpen(vaultTested, 3);
        assertClose(vaultTested);
        assertClaimDeposit(vaultTested, user5.addr, user5.addr, assets);
    }

    // claim with something to claim and vault is paused
    function test_whenClaimDepWithSomethingToClaimAndVaultIsPaused() external {
        // it should revert with EnforcedPause
        usersDealApproveAndDeposit(vaultTested, 4);
        assertClose(vaultTested);
        uint256 assets =
            IERC20Metadata(vaultTested.asset()).balanceOf(user1.addr);
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, assets, ""
        );
        assertOpen(vaultTested, 3);
        pause(vaultTested);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vaultTested.claimDeposit(user1.addr);
    }
}
