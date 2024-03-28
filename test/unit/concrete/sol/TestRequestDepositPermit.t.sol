// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { PermitParams, SyncVault } from "@src/SyncVault.sol";
import { SigUtils } from "@test/utils/SigUtils.sol";
import { ERC20Permit } from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract SyntheticPermit is TestBase {
    uint256 internal _deadline = block.timestamp + 1000;

    function test_BasicUsdcPermit() public {
        address spender = address(vaultTested);
        _executePermit(underlyingPermit, user1, spender, 10 * 1e6, _deadline);
        assertEq(underlyingPermit.allowance(user1.addr, spender), 10 * 1e6);
        assertEq(underlyingPermit.nonces(user1.addr), 1);
    }

    function test_depositWithPermit() public {
        usersDeal(vaultTested, 1);

        assertDepositWithPermit(
            vaultTested, user1.addr, user1.addr, 1000 * 1e6, _deadline
        );
    }

    function test_depositWithPermitWithReceiverDiffMsgSender() public {
        usersDeal(vaultTested, 1);

        assertDepositWithPermit(
            vaultTested, user1.addr, user2.addr, 1000 * 1e6, _deadline
        );
    }

    function test_givenVaultClosed_depositWithPermit() public {
        usersDealApproveAndDeposit(vaultTested, 1);
        close(vaultTested);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            user1,
            address(vaultTested),
            1,
            underlyingPermit.nonces(user1.addr),
            _deadline
        );

        vm.startPrank(user1.addr);
        PermitParams memory params =
            PermitParams({ value: 1, deadline: _deadline, v: v, r: r, s: s });
        vm.expectRevert(
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxDeposit.selector, user1.addr, 1, 0
            )
        );
        vaultTested.depositWithPermit(1, user1.addr, params);
    }

    function test_givenVaultPaused_depositWithPermit() public {
        usersDealApproveAndDeposit(vaultTested, 1);
        pause(vaultTested);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            user1,
            address(vaultTested),
            1,
            underlyingPermit.nonces(user1.addr),
            _deadline
        );

        vm.startPrank(user1.addr);
        PermitParams memory params =
            PermitParams({ value: 1, deadline: _deadline, v: v, r: r, s: s });
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vaultTested.depositWithPermit(1, user1.addr, params);
    }
}
