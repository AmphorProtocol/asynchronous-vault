// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestSharesBalanceInAsset is TestBase {
    function test_GivenUserHas0Shares() external {
        // it should return 0
        assertEq(vaultUSDC.sharesBalanceInAsset(user1.addr), 0);
    }

    function test_GivenUserHas10SharesAndPPSIsP() external {
        // it should return 10 * p
        usersDealApproveAndDeposit(1);
        uint256 sharesBalance = vaultUSDC.balanceOf(user1.addr);
        uint256 assetBalance = vaultUSDC.convertToAssets(sharesBalance);
        assertEq(vaultUSDC.sharesBalanceInAsset(user1.addr), assetBalance);
    }

    function test_GivenUserHas10SharesAndThereIsAProfit() external {
        // it should return 10 * p
        usersDealApproveAndDeposit(1);
        uint256 sharesBalance = vaultUSDC.balanceOf(user1.addr);
        closeVaults();
        assertOpen(vaultUSDC, 10);
        uint256 assetBalance = vaultUSDC.convertToAssets(sharesBalance);
        assertEq(vaultUSDC.sharesBalanceInAsset(user1.addr), assetBalance);
    }
}
