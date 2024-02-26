// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault } from "../../../Base.t.sol";

contract TestClose2 is TestBase {
    function setUp() public {
        usersDealApproveAndDeposit(1); // vault should not be empty
    }
}
