// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";

contract TestPreviewClaimRedeem is TestBase {
    function setUp() external {
        usersDealApproveAndDeposit(vaultTested, 1);
    }

    function test_GivenNoRequestMade() external {
        // it should return 0
        assertEq(vaultTested.previewClaimRedeem(user1.addr), 0);
    }

    function test_GivenRequestMade() external {
        // it should return the amount of assets that can be claimed
        close(vaultTested);
        uint256 shares = 1000;
        assertRequestRedeem(
            vaultTested, user1.addr, user1.addr, user1.addr, shares, ""
        );
        assertOpen(vaultTested, 1);
        assertApproxEqAbs(vaultTested.previewClaimRedeem(user1.addr), shares, 1);
    }
}
