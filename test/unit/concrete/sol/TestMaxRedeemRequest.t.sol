// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestMaxRedeemRequest {
    function test_GivenVaultOpenWhenMaxRedeemRequest() external {
        // it should return 0
    }

    function test_GivenVaultPausedWhenMaxRedeemRequest() external {
        // it should return 0
    }

    function test_GivenVaultClosedAndPausedWhenMaxRedeemRequest() external {
        // it should return 0
    }

    function test_GivenVaultClosedAndNotPausedWhenMaxRedeemRequest() external {
        // it should return the owner shares balance
    }
}
