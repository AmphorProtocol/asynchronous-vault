// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestTotalPendingRedeems {
    function test_GivenVaultOpenWhenTotalPendingRedeems() external {
        // it should return 0
    }

    function test_GivenVaultClosedWhenTotalPendingRedeems() external {
        // it should return shares balance of vault
    }
}
