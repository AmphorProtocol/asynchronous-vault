// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, IERC20Metadata } from "../../../Base.t.sol";

contract TestClaimRedeem is TestBase {
    // claim with nothing to claim
    function test_whenClaimRedeemWithNothingToClaim2() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(1);
        usersDealApprove(2);
        assertClaimRedeem(vaultUSDC, user2.addr, user2.addr, 0);
    }

    // claim with something to claim
    function test_whenClaimRedeemWithSomethingToClaim() external {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(4);
        usersDealApprove(10);
        assertClose(vaultUSDC);
        uint256 assets =
            100 * 10 ** IERC20Metadata(vaultUSDC.asset()).decimals();
        assertRequestDeposit(
            vaultUSDC, user5.addr, user5.addr, user5.addr, assets, ""
        );
        assertOpen(vaultUSDC, 3);
        assertClaimDeposit(vaultUSDC, user5.addr, user5.addr, assets);
    }

    function test_whenClaimRedeemWithSomethingToClaimAndVaultIsClosed()
        external
    {
        // it should revert with ERC4626ExceededMaxClaim
        usersDealApproveAndDeposit(4);
        usersDealApprove(5);
        assertClose(vaultUSDC);
        uint256 assets =
            100 * 10 ** IERC20Metadata(vaultUSDC.asset()).decimals();
        assertRequestDeposit(
            vaultUSDC, user5.addr, user5.addr, user5.addr, assets, ""
        );
        assertOpen(vaultUSDC, 3);
        assertClose(vaultUSDC);
        assertClaimDeposit(vaultUSDC, user5.addr, user5.addr, assets);
    }

    // claim with something to claim and vault is paused
    function test_whenClaimRedeemWithSomethingToClaimAndVaultIsPaused()
        external
    {
        // it should revert with EnforcedPause
        usersDealApproveAndDeposit(4);
        assertClose(vaultUSDC);
        uint256 assets =
            100 * 10 ** IERC20Metadata(vaultUSDC.asset()).decimals();
        assertRequestDeposit(
            vaultUSDC, user1.addr, user1.addr, user1.addr, assets, ""
        );
        assertOpen(vaultUSDC, 3);
        pause(vaultUSDC);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vaultUSDC.claimDeposit(user1.addr);
    }
}
