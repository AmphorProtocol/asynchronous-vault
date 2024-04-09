// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase, SyncVault, IERC20 } from "../../../Base.t.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TestMintPure is TestBase {
    function test_GivenVaultClosedWhenMint() external {
        // it should revert with ERC4626ExceededMaxMint
        usersDealApproveAndDeposit(vaultTested, 1); // vault should not be empty
        close(vaultTested);
        mintRevert(
            vaultTested,
            user1,
            1,
            // SyncVault.ERC4626ExceededMaxDeposit.selector
            abi.encodeWithSelector(
                SyncVault.ERC4626ExceededMaxMint.selector, user1.addr, 1, 0
            )
        );
    }

    function test_GivenRequiredAssetsHigherThanOwnerAllowanceToTheVaultWhenDeposit(
    )
        external
    {
        // it should revert with ERC20InsufficientAllowance
        mintRevert(
            vaultTested,
            user1,
            IERC20(vaultTested.asset()).allowance(
                user1.addr, address(vaultTested)
            ) + 1
        );
    }

    function test_GivenRequiredAssetsHigherThanOwnerBalanceWhenDeposit()
        external
    {
        // it should revert with ERC20InsufficientBalance
        mintRevert(
            vaultTested,
            user1,
            IERC20(vaultTested.asset()).balanceOf(user1.addr) + 1
        );
    }

    function test_GivenVaultPausedWhenMint() external {
        // it should revert with EnforcedPause
        pause(vaultTested);
        mintRevert(vaultTested, user1, 1, Pausable.EnforcedPause.selector);
    }

    function test_GivenReceiverIsAddress0WhenMint() external {
        // it should revert with ERC20InvalidReceiver
        usersDealApprove(vaultTested, 1);
        mintRevert(vaultTested, address0, 1);
    }

    function test_GivenPreviewMintIsHigherThanTheAllowanceOfTheOwnerToTheVaultWhenMint(
    )
        external
    {
        // it should revert with ERC20InsufficientAllowance
        mintRevert(
            vaultTested,
            user1,
            IERC20(vaultTested.asset()).allowance(
                user1.addr, address(vaultTested)
            ) + 1
        );
    }

    function test_GivenRequestedAmountOfSharesConvertedInAssetIsHigherThanTheBalanceOfTheOwnerWhenMint(
    )
        external
    {
        // it should revert with ERC20InsufficientBalance
        mintRevert(
            vaultTested,
            user1,
            IERC20(vaultTested.asset()).balanceOf(user1.addr) + 1
        );
    }

    function test_GivenVaultOpenWhenMint() external {
        usersDealApprove(vaultTested, 1);
        uint256 decimals = IERC20Metadata(vaultTested.asset()).decimals();
        assertMint(vaultTested, user1.addr, user1.addr, 1 ** 10 ** decimals);
    }

    function test_GivenReceiverNotEqualOwnerWhenMint() external {
        // it should pass like above
        usersDealApprove(vaultTested, 1);
        uint256 decimals = IERC20Metadata(vaultTested.asset()).decimals();
        assertMint(vaultTested, user1.addr, user2.addr, 1 ** 10 ** decimals);
    }

    function test_GivenVaultEmptyWhenMint() external {
        // it should pass like above
        usersDealApprove(vaultTested, 1);
        uint256 decimals = IERC20Metadata(vaultTested.asset()).decimals();
        assertMint(vaultTested, user1.addr, user1.addr, 1 ** 10 ** decimals);
    }

    function test_GivenDepositAmountIs0WhenMint() external {
        // it should pass like above
        usersDealApprove(vaultTested, 1);
        assertMint(vaultTested, user1.addr, user1.addr, 0);
    }
}
