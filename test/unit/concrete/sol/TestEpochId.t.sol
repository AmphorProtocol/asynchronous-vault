// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestEpochId is TestBase {
    function test_GivenEpochIdEquals10GivenRequestIdEquals10WhenIsCurrentEpoch()
        external
    {
        // it should not revert
        // it should returns true
        usersDealApproveAndDeposit(vaultTested, 1);
        for (uint256 i = 1; i < 11; i++) {
            close(vaultTested);
            uint256 epochId = vaultTested.epochId();
            assertEq(epochId, i, "isCurrentEpoch");
            assertOpen(vaultTested, 0);
        }
    }
}
