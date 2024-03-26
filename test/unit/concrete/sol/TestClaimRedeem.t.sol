// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, IERC20Metadata } from "../../../Base.t.sol";

contract TestClaimRedeem is TestBase {
    // claim with nothing to claim
    function test_whenClaimRedeemWithNothingToClaim2() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 1);
        usersDealApprove(vaultTested, 2);
        // assertClaimRedeem(vaultTested, user2.addr, user2.addr, 0); // revert -> NoClaimAvailable
    }

    // claim with something to claim
    function test_whenClaimRedeemWithSomethingToClaim() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 4);
        usersDealApprove(vaultTested, 10);
        assertClose(vaultTested);
        uint256 shares = vaultTested.balanceOf(user5.addr);

        assertRequestRedeem(
            vaultTested, user5.addr, user5.addr, user5.addr, shares, ""
        );
        assertOpen(vaultTested, 3);
        
        vm.startPrank(user5.addr);
        vaultTested.claimRedeem(user5.addr);
        vm.stopPrank();
        //assertClaimRedeem(vaultTested, user5.addr, user5.addr, shares);
    }

    function test_whenClaimRedeemWithSomethingToClaimAndVaultIsClosed()
        external
    {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 4);
        usersDealApprove(vaultTested, 5);
        assertClose(vaultTested);
        uint256 shares = vaultTested.balanceOf(user5.addr);

        assertRequestRedeem(
            vaultTested, user5.addr, user5.addr, user5.addr, shares, ""
        );
        assertOpen(vaultTested, 3);
        assertClose(vaultTested);
        assertClaimRedeem(vaultTested, user5.addr, user5.addr, shares);
    }

    // claim with something to claim and vault is paused
    function test_whenClaimRedeemWithSomethingToClaimAndVaultIsPaused()
        external
    {
        // it should revert with EnforcedPause
        usersDealApproveAndDeposit(vaultTested, 4);
        assertClose(vaultTested);
        uint256 shares = vaultTested.balanceOf(user1.addr);
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, shares, ""
        );
        assertOpen(vaultTested, 3);
        pause(vaultTested);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vaultTested.claimRedeem(user1.addr);
    }

    function test_whenClaimRedeemWithSomethingToClaim2Times() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(vaultTested, 5);
        usersDealApprove(vaultTested, 10);
        assertClose(vaultTested);
        uint256 shares = vaultTested.balanceOf(user5.addr);

        assertRequestRedeem(
            vaultTested, user5.addr, user5.addr, user5.addr, shares, ""
        );

        assertOpen(vaultTested, 3);
        // assertClaimRedeem(vaultTested, user5.addr, user5.addr, shares);
        uint256 assets =
            IERC20Metadata(vaultTested.asset()).balanceOf(user5.addr);

        uint256 assetsAfter =
            IERC20Metadata(vaultTested.asset()).balanceOf(user5.addr);
        // assertEq(assets, assetsAfter);
    }
}
