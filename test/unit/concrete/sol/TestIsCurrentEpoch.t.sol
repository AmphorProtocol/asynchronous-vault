// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestIsCurrentEpoch {
    function test_GivenEpochIdEquals10GivenRequestIdEquals10WhenIsCurrentEpoch()
        external
    {
        // it should not revert
        // it should returns true
    }

    function test_GivenEpochIdEquals10GivenRequestIdEquals9WhenIsCurrentEpoch()
        external
    {
        // it should not revert
        // it should returns false
    }

    function test_GivenEpochIdEquals9GivenRequestIdEquals10WhenIsCurrentEpoch()
        external
    {
        // it should not revert
        // it should returns false
    }
}
