// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestClose {
    function test_GivenVaultIsClosedWhenClose() external {
        // it should revert with VaultIsLocked
    }

    function test_GivenMsgSenderIsNotOwnerWhenClose() external {
        // it should revert with OwnableUnauthorizedAccount(msg.sender)
    }

    function test_GivenTotalsAssetsIsXWhenOpen() external {
        // it should increase owner's underlying balance by x
    }

    function test_WhenCloseSucceed() external {
        // it should set isOpen to false
        // it should emit EpochStart(block.timestamp, _totalAssets, totalSupply())
        // it should verify totalAssets == totalsAssetsBefore
        // it should verify totalSupply == totalSupplyBefore
    }
}
