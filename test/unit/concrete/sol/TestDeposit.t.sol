// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, IERC20 } from "../../../Base.t.sol";
import { console } from "forge-std/console.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract TestDeposit is TestBase {
    function test_GivenVaultClosedWhenDeposit() external {
        // it should revert with ERC4626ExceededMaxDeposit
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        // todo
        depositRevert(
            vaultTested,
            user1,
            1,
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxDeposit.selector,
                user1.addr,
                1,
                0
            )
        );
    }

    function test_GivenAmountHigherThanOwnerAllowanceToTheVaultWhenDeposit()
        external
    {
        // it should revert with ERC20InsufficientAllowance
        depositRevert(
            vaultTested,
            user1,
            IERC20(vaultTested.asset()).allowance(
                user1.addr, address(vaultTested)
            ) + 1
        );
    }

    function test_GivenAmountHigherThanOwnerBalanceWhenDeposit() external {
        usersDealApprove(vaultTested, 1); // vault should not be empty
        depositRevert(
            vaultTested,
            user1,
            IERC20(vaultTested.asset()).balanceOf(user1.addr) + 1
        );
    }

    function test_GivenVaultOpenGivenVaultPausedWhenDeposit() external {
        // it should revert with EnforcedPause
        pause(vaultTested);
        depositRevert(vaultTested, user1, Pausable.EnforcedPause.selector);
    }

    function test_GivenVaultClosedGivenPausedWhenDeposit() external {
        // it should revert with ERC4626ExceededMaxDeposit
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        pause(vaultTested);
        depositRevert(vaultTested, user1, Pausable.EnforcedPause.selector);
    }

    function test_GivenReceiverIsAddress0WhenDeposit() external {
        // it should revert with ERC20InvalidReceiver
        usersDealApprove(vaultTested, 1);
        depositRevert(vaultTested, address0, 1);
    }

    function test_GivenConditionsAreMetWhenDeposit() external {
        usersDealApprove(vaultTested, 1);
        assertDeposit(vaultTested, user1.addr, user1.addr, 1);
    }

    function test_GivenVaultOpenGivenReceiverNotEqualOwnerWhenDeposit()
        external
    {
        // it should pass the like as above
        usersDealApprove(vaultTested, 1);
        assertDeposit(vaultTested, user1.addr, user1.addr, 1);
    }

    function test_GivenVaultOpenGivenVaultEmptyWhenDeposit() external {
        // it should pass the like as above
        usersDealApprove(vaultTested, 1);
        assertDeposit(vaultTested, user1.addr, user1.addr, 1);
    }

    function test_GivenVaultOpenGivenDepositAmountEqual0WhenDeposit()
        external
    {
        // it should pass the like as above
        usersDealApprove(vaultTested, 1);
        assertDeposit(vaultTested, user1.addr, user1.addr, 1);
    }
}
