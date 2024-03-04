// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestClaimableDepositBalanceInAsset is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(1);
    }

    function test_GivenNoRequestMade() external {
        // it should return 0
        assertEq(
            vaultUSDC.claimableDepositBalanceInAsset(user1.addr),
            0
        );
    }

    function test_GivenRequestMade() external {
        // it should return the amount of assets that can be claimed
        closeVaults();
        uint256 assets = 1000;
        assertRequestDeposit(vaultUSDC, user1.addr, user1.addr, user1.addr, assets, "");
        // assertOpen(vaultUSDC, 1000);  // todo fix log error
        open(vaultUSDC, 0);
        assertEq(
            vaultUSDC.previewClaimDeposit(user1.addr),
            assets
        );
    }

    function test_claimableDepositBalanceInAsset() external {
        closeVaults();
        uint256 assets = 10000;
        assertRequestDeposit(vaultUSDC, user1.addr, user1.addr, user1.addr, assets, "");
        assertOpen(vaultUSDC, 0);
        assertEq(vaultUSDC.claimableDepositBalanceInAsset(user1.addr), assets);
    }

    function test_claimableDepositBalanceInAssetInProfit() external {
        closeVaults();
        uint256 assets = 10000; // todo : to be fuzzed
        assertRequestDeposit(
            vaultUSDC,
            user1.addr,
            user1.addr,
            user1.addr,
            assets,
            ""
        );
        open(vaultUSDC, 10);
        // assertOpen(vaultUSDC, 10); // todo fix log error

        assertApproxEqAbs(
            vaultUSDC.claimableDepositBalanceInAsset(user1.addr),
            assets, // rounding
            1
        );
    }

    function test_claimableDepositBalanceInAssetEmptyVault() external {
        assertEq(vaultUSDC.claimableDepositBalanceInAsset(user1.addr), 0);
    }
}

