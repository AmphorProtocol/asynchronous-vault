// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestClaimableDepositBalanceInAsset is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(vaultTested, 1);
    }

    function test_GivenNoRequestMade() external {
        // it should return 0
        assertEq(vaultTested.claimableDepositBalanceInAsset(user1.addr), 0);
    }

    function test_GivenRequestMade() external {
        // it should return the amount of assets that can be claimed
        close(vaultTested);
        uint256 assets = 1000;
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, assets, ""
        );
        assertOpen(vaultTested, 10);
        assertApproxEqAbs(
            vaultTested.previewClaimDeposit(user1.addr), assets, 1
        );
    }

    function test_claimableDepositBalanceInAsset() external {
        close(vaultTested);
        uint256 assets = 10_000;
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, assets, ""
        );
        assertOpen(vaultTested, 0);
        assertEq(vaultTested.claimableDepositBalanceInAsset(user1.addr), assets);
    }

    function test_claimableDepositBalanceInAssetInProfit() external {
        close(vaultTested);
        uint256 assets = 10_000; // todo : to be fuzzed
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, assets, ""
        );
        assertOpen(vaultTested, 10);

        assertApproxEqAbs(
            vaultTested.claimableDepositBalanceInAsset(user1.addr),
            assets, // rounding
            1
        );
    }

    function test_claimableDepositBalanceInAssetEmptyVault() external {
        assertEq(vaultTested.claimableDepositBalanceInAsset(user1.addr), 0);
    }
}
