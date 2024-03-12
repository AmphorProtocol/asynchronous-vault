// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, IERC20Metadata } from "../../Base.t.sol";

contract TestClaimDepositIntegration is TestBase {
    // claim with nothing to claim
    function test_whenClaimDepWithNothingToClaim(uint16 it) external {
        // it should revert with ERC4626ExceededMaxClaim
        vm.assume(it < 13);
        uint256 i = 0;
        while (i++ < it) {
            usersDealApproveAndDeposit(vaultTested, 5);
            usersDealApproveAndDeposit(vaultTested, 7);
            usersDealApproveAndDeposit(vaultTested, 10);

            assertClose(vaultTested);
            uint256 user1Dep = underlying.balanceOf(user1.addr) / 2;
            assertRequestDeposit(
                vaultTested, user1.addr, user1.addr, user1.addr, user1Dep, ""
            );
            uint256 user8Dep = underlying.balanceOf(user2.addr) / 4;
            assertRequestDeposit(
                vaultTested, user8.addr, user8.addr, user8.addr, user8Dep, ""
            );
            uint256 user3Dep = underlying.balanceOf(user3.addr) / 3;
            assertRequestDeposit(
                vaultTested, user3.addr, user3.addr, user3.addr, user3Dep, ""
            );

            assertOpen(vaultTested, int256(i * 14));
            assertClaimDeposit(vaultTested, user1.addr, user1.addr, user1Dep);
            assertClaimDeposit(vaultTested, user8.addr, user8.addr, user8Dep);
            assertClaimDeposit(vaultTested, user3.addr, user3.addr, user3Dep);
        }
    }

    function test_whenClaimWithClaimRedeemAndDeposit() external {
        // function test_whenClaimWithClaimRedeemAndDeposit(uint16 it) external
        // {
        // it should revert with ERC4626ExceededMaxClaim
        // vm.assume(it < 300);
        uint256 it = 60;
        uint256 i = 0;
        while (i++ < it) {
            usersDealApproveAndDeposit(vaultTested, 5);
            usersDealApproveAndDeposit(vaultTested, 7);
            usersDealApproveAndDeposit(vaultTested, 10);

            assertClose(vaultTested);
            uint256 user1Dep = underlying.balanceOf(user1.addr) / 2;
            assertRequestDeposit(
                vaultTested, user1.addr, user1.addr, user1.addr, user1Dep, ""
            );
            uint256 user2Redeem = vaultTested.balanceOf(user2.addr) / 17;
            assertRequestRedeem(
                vaultTested, user2.addr, user2.addr, user2.addr, user2Redeem, ""
            );
            uint256 user3Dep = underlying.balanceOf(user3.addr) / 3;
            assertRequestDeposit(
                vaultTested, user3.addr, user3.addr, user3.addr, user3Dep, ""
            );
            uint256 user4Redeem = vaultTested.balanceOf(user4.addr) / 5;
            assertRequestRedeem(
                vaultTested, user4.addr, user4.addr, user4.addr, user4Redeem, ""
            );

            uint256 user8Dep = underlying.balanceOf(user2.addr) / 4;
            assertRequestDeposit(
                vaultTested, user8.addr, user8.addr, user8.addr, user8Dep, ""
            );
            uint256 user5Redeem = vaultTested.balanceOf(user5.addr) / 6;
            assertRequestRedeem(
                vaultTested, user5.addr, user5.addr, user5.addr, user5Redeem, ""
            );

            assertOpen(vaultTested, int256(5 * (i % 4)));
            assertClaimDeposit(vaultTested, user1.addr, user1.addr, user1Dep);
            assertClaimDeposit(vaultTested, user8.addr, user8.addr, user8Dep);
            assertClaimDeposit(vaultTested, user3.addr, user3.addr, user3Dep);

            assertClaimRedeem(vaultTested, user2.addr, user2.addr, user2Redeem);
            assertClaimRedeem(vaultTested, user4.addr, user4.addr, user4Redeem);
            assertClaimRedeem(vaultTested, user5.addr, user5.addr, user5Redeem);
        }
    }

    function test_whenClaimWithClaimRedeemAndDepositWithRedeemBigger()
        external
    {
        uint256 it = 60;
        uint256 i = 0;
        while (i++ < it) {
            usersDealApproveAndDeposit(vaultTested, 5);
            usersDealApproveAndDeposit(vaultTested, 7);
            usersDealApproveAndDeposit(vaultTested, 10);

            assertClose(vaultTested);
            uint256 user1Dep = underlying.balanceOf(user1.addr) / 2;
            assertRequestDeposit(
                vaultTested, user1.addr, user1.addr, user1.addr, user1Dep, ""
            );
            uint256 user2Redeem = vaultTested.balanceOf(user2.addr);
            assertRequestRedeem(
                vaultTested, user2.addr, user2.addr, user2.addr, user2Redeem, ""
            );
            uint256 user3Dep = underlying.balanceOf(user3.addr) / 3;
            assertRequestDeposit(
                vaultTested, user3.addr, user3.addr, user3.addr, user3Dep, ""
            );
            uint256 user4Redeem = vaultTested.balanceOf(user4.addr);
            assertRequestRedeem(
                vaultTested, user4.addr, user4.addr, user4.addr, user4Redeem, ""
            );

            uint256 user8Dep = underlying.balanceOf(user2.addr) / 4;
            assertRequestDeposit(
                vaultTested, user8.addr, user8.addr, user8.addr, user8Dep, ""
            );
            uint256 user5Redeem = vaultTested.balanceOf(user5.addr);
            assertRequestRedeem(
                vaultTested, user5.addr, user5.addr, user5.addr, user5Redeem, ""
            );

            assertOpen(vaultTested, int256(5 * (i % 4)));
            assertClaimDeposit(vaultTested, user1.addr, user1.addr, user1Dep);
            assertClaimDeposit(vaultTested, user8.addr, user8.addr, user8Dep);
            assertClaimDeposit(vaultTested, user3.addr, user3.addr, user3Dep);

            assertClaimRedeem(vaultTested, user2.addr, user2.addr, user2Redeem);
            assertClaimRedeem(vaultTested, user4.addr, user4.addr, user4Redeem);
            assertClaimRedeem(vaultTested, user5.addr, user5.addr, user5Redeem);
        }
    }

    function test_whenClaimWithClaimRedeemAndDepositEquals() external {
        uint256 it = 60;
        uint256 i = 0;
        while (i++ < it) {
            usersDealApproveAndDeposit(vaultTested, 5);
            usersDealApproveAndDeposit(vaultTested, 7);
            usersDealApproveAndDeposit(vaultTested, 10);

            assertClose(vaultTested);
            uint256 user1Dep = underlying.balanceOf(user1.addr);
            assertRequestDeposit(
                vaultTested, user1.addr, user1.addr, user1.addr, user1Dep, ""
            );
            uint256 user2Redeem = vaultTested.balanceOf(user2.addr);
            assertRequestRedeem(
                vaultTested, user2.addr, user2.addr, user2.addr, user2Redeem, ""
            );

            assertOpen(vaultTested, 0);
            assertClaimDeposit(vaultTested, user1.addr, user1.addr, user1Dep);

            assertClaimRedeem(vaultTested, user2.addr, user2.addr, user2Redeem);
        }
    }

    // claim with something to claim

    //     function test_whenClaimDepWithSomethingToClaim(
    //         uint256 depositAmount,
    //         int256 performanceInBips
    //     )
    //         external
    //     {
    //         // it should revert with ERC4626ExceededMaxClaim
    //         vm.assume(depositAmount < 1 * 10 ** (vaultTested.decimals() +
    // 1));
    //         // vm.assume(redeemAmount < vaultTested.balanceOf(user2.addr));
    //         vm.assume(performanceInBips > -3000 && performanceInBips <
    // 10_000);
    //         usersDealApproveAndDeposit(vaultTested, 5);
    //         usersDealApprove(vaultTested, 10);
    //         assertClose(vaultTested);
    //         uint256 assets =
    //             IERC20Metadata(vaultTested.asset()).balanceOf(user5.addr);
    //         assertRequestDeposit(
    //             vaultTested, user5.addr, user5.addr, user5.addr, assets, ""
    //         );
    //         assertOpen(vaultTested, performanceInBips);
    //         assertClaimDeposit(vaultTested, user5.addr, user5.addr, assets);
    //     }

    //     function test_whenClaimDepWithSomethingToClaimAndVaultIsClosed()
    // external {
    //         // it should revert with ERC4626ExceededMaxClaim
    //         usersDealApproveAndDeposit(vaultTested, 4);
    //         usersDealApprove(vaultTested, 5);
    //         assertClose(vaultTested);
    //         uint256 assets =
    //             IERC20Metadata(vaultTested.asset()).balanceOf(user5.addr);
    //         assertRequestDeposit(
    //             vaultTested, user5.addr, user5.addr, user5.addr, assets, ""
    //         );
    //         assertOpen(vaultTested, 3);
    //         assertClose(vaultTested);
    //         assertClaimDeposit(vaultTested, user5.addr, user5.addr, assets);
    //     }

    //     // claim with something to claim and vault is paused
    //     function test_whenClaimDepWithSomethingToClaimAndVaultIsPaused()
    // external {
    //         // it should revert with EnforcedPause
    //         usersDealApproveAndDeposit(vaultTested, 4);
    //         assertClose(vaultTested);
    //         uint256 assets =
    //             IERC20Metadata(vaultTested.asset()).balanceOf(user1.addr);
    //         assertRequestDeposit(
    //             vaultTested, user1.addr, user1.addr, user1.addr, assets, ""
    //         );
    //         assertOpen(vaultTested, 3);
    //         pause(vaultTested);
    //         vm.startPrank(user1.addr);
    //         vm.expectRevert();
    //         vaultTested.claimDeposit(user1.addr);
    //     }
}
