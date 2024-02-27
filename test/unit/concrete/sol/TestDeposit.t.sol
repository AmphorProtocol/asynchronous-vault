// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncSynthVault, IERC20 } from "../../../Base.t.sol";
import { console } from "forge-std/console.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract TestDeposit is TestBase {
    function test_GivenVaultClosedWhenDeposit() external {
        // it should revert with ERC4626ExceededMaxDeposit
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        // todo
        depositRevert(
            vaultUSDC,
            user1,
            1,
            abi.encodeWithSelector(
                SyncSynthVault.ERC4626ExceededMaxDeposit.selector,
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
            vaultUSDC,
            user1,
            IERC20(vaultUSDC.asset()).allowance(user1.addr, address(vaultUSDC))
                + 1
        );
    }

    function test_GivenAmountHigherThanOwnerBalanceWhenDeposit() external {
        usersDealApprove(1); // vault should not be empty
        depositRevert(
            vaultUSDC,
            user1,
            IERC20(vaultUSDC.asset()).balanceOf(user1.addr) + 1
        );
    }

    function test_GivenVaultOpenGivenVaultPausedWhenDeposit() external {
        // it should revert with EnforcedPause
        pause(vaultUSDC);
        depositRevert(vaultUSDC, user1, Pausable.EnforcedPause.selector);
    }

    function test_GivenVaultClosedGivenPausedWhenDeposit() external {
        // it should revert with ERC4626ExceededMaxDeposit
        usersDealApproveAndDeposit(1); // vault should not be empty
        closeVaults();
        pause(vaultUSDC);
        depositRevert(vaultUSDC, user1, Pausable.EnforcedPause.selector);
    }

    function test_GivenReceiverIsAddress0WhenDeposit() external {
        // it should revert with ERC20InvalidReceiver
        usersDealApprove(1);
        depositRevert(vaultUSDC, address0, 1);
    }

    function test_GivenConditionsAreMetWhenDeposit() external {
        usersDealApprove(1);
        assertDeposit(vaultUSDC, user1.addr, user1.addr, 1);
    }

    function test_GivenVaultOpenGivenReceiverNotEqualOwnerWhenDeposit()
        external
    {
        // it should pass the like as above
        usersDealApprove(1);
        assertDeposit(vaultUSDC, user1.addr, user1.addr, 1);
    }

    function test_GivenVaultOpenGivenVaultEmptyWhenDeposit() external {
        // it should pass the like as above
        usersDealApprove(1);
        assertDeposit(vaultUSDC, user1.addr, user1.addr, 1);
    }

    function test_GivenVaultOpenGivenDepositAmountEqual0WhenDeposit()
        external
    {
        // it should pass the like as above
        usersDealApprove(1);
        assertDeposit(vaultUSDC, user1.addr, user1.addr, 1);
    }
}
