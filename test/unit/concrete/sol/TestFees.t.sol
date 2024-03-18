// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, IERC20 } from "../../../Base.t.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TestClaimAndRequestDeposit is TestBase {
    function test_perfFeesOver30() public {
        vm.startPrank(amphorLabs);
        vm.expectRevert(SyncVault.FeesTooHigh.selector);
        vaultTested.setFee(31 * 100);
        vm.stopPrank();
    }

    function test_perfFeesUnder30() public {
        vm.startPrank(amphorLabs);
        vaultTested.setFee(30 * 100);
        assertEq(vaultTested.feesInBps(), 30 * 100);
    }
}
