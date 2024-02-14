// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestSharesBalanceInAsset {
    function test_GivenUserHas0Shares() external {
        // it should return 0
    }

    function test_GivenUserHas10SharesAndPPSIsP() external {
        // it should return 10 * p
    }

    function test_GivenUserHas10SharesAndAndConvertToAssetsOf10IsN() external {
        // it should return n
    }
}
