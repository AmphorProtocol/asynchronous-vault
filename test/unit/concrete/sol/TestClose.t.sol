// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault } from "../../../Base.t.sol";

contract TestClose is TestBase {

    function setUp() public {
        usersDealApproveAndDeposit(1); // vault should not be empty
    }

    function test_GivenVaultIsClosedWhenClose() external {
        // it should revert with VaultIsLocked
        closeVaults();
        closeRevertLocked(vaultUSDC);
    }

    function test_GivenMsgSenderIsNotOwnerWhenClose() external {
        // it should revert with OwnableUnauthorizedAccount(msg.sender)
        closeRevertUnauthorized(vaultUSDC);
    }

    function test_WhenCloseSucceed() external {
        // it should set isOpen to false
        // it should emit EpochStart(block.timestamp, _totalAssets, totalSupply())
        // it should verify totalAssets == totalsAssetsBefore
        // it should verify totalSupply == totalSupplyBefore
        uint256 totalAssetsBefore = vaultUSDC.totalAssets();
        uint256 totalSupplyBefore = vaultUSDC.totalSupply();
        closeVaults();
        assertEq(vaultUSDC.isOpen(), false);
        // todo check the event
        assertEq(vaultUSDC.totalAssets(), totalAssetsBefore);
        assertEq(vaultUSDC.totalSupply(), totalSupplyBefore);
    }
}
