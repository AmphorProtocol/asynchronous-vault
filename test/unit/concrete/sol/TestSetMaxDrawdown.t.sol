// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestSetMaxDrawdown is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(vaultTested, 1);
    }

    function test_WhenSetMaxDrawdownNotOwner() external {
        // it should revert with OwnableUnauthorizedAccount(msg.sender)
        vm.prank(user1.addr);
        vm.expectRevert();
        vaultTested.setMaxDrawdown(1);
    }


    // Working but you need to pass _maxDrawdown in public
    // function test_WhenSetMaxDrawdownSucceed() external {
    //     // it should set max drawdown
    //     address owner = vaultTested.owner();
    //     vm.startPrank(owner);
    //     vaultTested.setMaxDrawdown(1);
    //     assertEq(vaultTested._maxDrawdown(), 1);
    // }

    // function test_WhenSetMaxDrawdownSucceedAndIs0() external {
    //     // it should set max drawdown
    //     address owner = vaultTested.owner();
    //     vm.startPrank(owner);
    //     vaultTested.setMaxDrawdown(0);
    //     assertEq(vaultTested._maxDrawdown(), 0);
    // }

    function test_WhendMaxDrawdownIsMaxValue() external {
        // it should revert
        address owner = vaultTested.owner();
        vm.expectRevert();
        vm.startPrank(owner);
        vaultTested.setMaxDrawdown(10001);
    }
}
