// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import "forge-std/console.sol";

contract TestClaimableDepositBalanceInAsset is TestBase {
    function test_claimableDepositBalanceInAsset() external {
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        uint256 assets = 10000;
        assertRequestDeposit(vaultUSDC, user1.addr, user1.addr, user1.addr, assets, "");
        assertOpen(vaultUSDC, 0);
        assertEq(vaultUSDC.claimableDepositBalanceInAsset(user1.addr), assets);
    }

    function test_claimableDepositBalanceInAssetInProfit() external {
        usersDealApproveAndDeposit(1); // vault should not be empty
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

