// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestPreviewClaimDeposit is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(vaultTested, 1);
    }

    function test_GivenNoRequestMade() external {
        // it should return 0
        assertEq(vaultTested.previewClaimDeposit(user1.addr), 0);
    }

    function test_GivenRequestMade() external {
        // it should return the amount of assets that can be claimed
        close(vaultTested);
        uint256 assets = 1000;
        assertRequestDeposit(
            vaultTested, user1.addr, user1.addr, user1.addr, assets, ""
        );
        assertOpen(vaultTested, 0);
        assertApproxEqAbs(
            vaultTested.previewClaimDeposit(user1.addr), assets, 1
        );
    }
}
