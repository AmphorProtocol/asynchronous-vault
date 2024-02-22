// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestTotalPendingDeposits {
    function test_GivenVaultOpenWhenTotalPendingDeposits() external {
        // it should return 0
    }

    function test_GivenVaultClosedWhenTotalPendingDeposits() external {
        // it should return underlying balance of vault
    }
}
