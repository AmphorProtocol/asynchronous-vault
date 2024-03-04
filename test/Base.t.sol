//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { AssertionsRequest } from "./utils/assertions/AssertionsRequest.sol";
import { console } from "forge-std/console.sol";
import { AsyncSynthVault, SyncSynthVault } from "../src/AsyncSynthVault.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract TestBase is AssertionsRequest {
    // OWNER ACTIONS //

    function close(AsyncSynthVault vault) internal {
        address owner = vault.owner();
        vm.prank(owner);
        vault.close();
    }

    function closeRevertUnauthorized(AsyncSynthVault vault) internal {
        address user = users[0].addr;
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        vault.close();
        vm.stopPrank();
    }

    function pause(AsyncSynthVault vault) internal {
        address owner = vault.owner();
        vm.prank(owner);
        vault.pause();
    }

    function unpause(AsyncSynthVault vault) internal {
        address owner = vault.owner();
        vm.prank(owner);
        vault.unpause();
    }

    // USERS ACTIONS //

    function mint(AsyncSynthVault vault, VmSafe.Wallet memory user) internal {
        mint(vault, user, USDC.balanceOf(user.addr));
    }

    function deposit(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user
    )
        internal
    {
        deposit(vault, user, USDC.balanceOf(user.addr));
    }

    function depositRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        bytes4 selector
    )
        internal
    {
        depositRevert(vault, user, USDC.balanceOf(user.addr), selector);
    }

    function depositRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        bytes memory revertData
    )
        internal
    {
        depositRevert(vault, user, USDC.balanceOf(user.addr), revertData);
    }

    function depositRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes4 selector
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(selector);
        vault.deposit(amount, user.addr);
    }

    function depositRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert();
        vault.deposit(amount, user.addr);
    }

    function depositRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes memory revertData
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(revertData);
        vault.deposit(amount, user.addr);
    }

    function mintRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes4 selector
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(selector);
        vault.mint(amount, user.addr);
    }

    function mintRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert();
        vault.mint(amount, user.addr);
    }

    function mintRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes memory revertData
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(revertData);
        vault.mint(amount, user.addr);
    }

    function redeem(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user
    )
        internal
    {
        redeem(vault, user, vault.balanceOf(user.addr));
    }

    function mint(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.mint(amount, user.addr);
    }

    function deposit(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        private
    {
        vm.startPrank(user.addr);
        vault.deposit(amount, user.addr);
    }

    function withdraw(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.withdraw(amount, user.addr, user.addr);
    }

    function withdraw(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user
    )
        internal
    {
        withdraw(vault, user, USDC.balanceOf(user.addr));
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        bytes4 selector
    )
        internal
    {
        withdrawRevert(vault, user, USDC.balanceOf(user.addr), selector);
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user
    )
        internal
    {
        withdrawRevert(vault, user, USDC.balanceOf(user.addr));
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        bytes memory revertData
    )
        internal
    {
        withdrawRevert(vault, user, USDC.balanceOf(user.addr), revertData);
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory owner,
        VmSafe.Wallet memory sender,
        uint256 amount,
        bytes4 selector
    )
        internal
    {
        vm.startPrank(sender.addr);
        vm.expectRevert(selector);
        vault.withdraw(amount, owner.addr, owner.addr);
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory owner,
        VmSafe.Wallet memory sender,
        uint256 amount,
        bytes memory revertData
    )
        internal
    {
        vm.startPrank(sender.addr);
        vm.expectRevert(revertData);
        vault.withdraw(amount, owner.addr, owner.addr);
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes4 selector
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(selector);
        vault.withdraw(amount, user.addr, user.addr);
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes memory revertData
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(revertData);
        vault.withdraw(amount, user.addr, user.addr);
    }

    function withdrawRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert();
        vault.withdraw(amount, user.addr, user.addr);
    }

    function redeemRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 shares,
        bytes memory revertData
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(revertData);
        vault.redeem(shares, user.addr, user.addr);
    }

    function redeemRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory receiver,
        VmSafe.Wallet memory owner,
        uint256 shares,
        bytes memory revertData
    )
        internal
    {
        vm.startPrank(owner.addr);
        vm.expectRevert(revertData);
        vault.redeem(shares, receiver.addr, receiver.addr);
    }

    function redeemRevert(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes4 selector
    )
        internal
    {
        vm.startPrank(user.addr);
        vm.expectRevert(selector);
        vault.redeem(amount, user.addr, user.addr);
    }

    function redeem(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 shares
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.redeem(shares, user.addr, user.addr);
    }

    function requestDeposit(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes memory data
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.requestDeposit(amount, user.addr, user.addr, data);
    }

    function requestRedeem(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount,
        bytes memory data
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.requestRedeem(amount, user.addr, user.addr, data);
    }

    function decreaseDepositRequest(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.decreaseDepositRequest(amount, user.addr);
    }

    function decreaseRedeemRequest(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        internal
    {
        decreaseRedeemRequest(vault, user, user, amount);
    }

    function decreaseRedeemRequest(
        AsyncSynthVault vault,
        VmSafe.Wallet memory user,
        VmSafe.Wallet memory receiver,
        uint256 amount
    )
        internal
    {
        vm.startPrank(user.addr);
        vault.decreaseRedeemRequest(amount, receiver.addr);
    }

    // USERS CONFIGURATION //

    function usersDealApproveAndDeposit(
        IERC4626 vault,
        uint256 userMax
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        usersDealApprove(vault, userMax);
        usersDeposit(vault, userMax);
    }

    function usersDealApproveAndRequestDeposit(
        AsyncSynthVault vault,
        uint256 userMax
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        usersDealApprove(vault, userMax);
        usersRequestDeposit(vault, userMax, "");
    }

    function usersDealApproveAndRequestDeposit(
        AsyncSynthVault vault,
        uint256 userMax,
        bytes memory data
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        usersDealApprove(vault, userMax);
        usersRequestDeposit(vault, userMax, data);
    }

    function usersDealApproveAndRequestRedeem(
        AsyncSynthVault vault,
        uint256 userMax
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        usersDealApprove(vault, userMax);
        usersRequestRedeem(vault, userMax);
    }

    function usersDealApproveAndRequestRedeem(
        AsyncSynthVault vault,
        uint256 userMax,
        bytes memory data
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        // usersDealApprove(userMax);
        usersRequestRedeem(vault, userMax, data);
    }

    function usersDeposit(IERC4626 vault, uint256 userMax) internal {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _depositInVault(vault, users[i].addr);
        }
    }

    function usersRequestWithdraw(
        AsyncSynthVault vault,
        uint256 userMax,
        bytes memory data
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _requestRedeemInVaults(vault, users[i].addr, data);
        }
    }

    function usersRequestDeposit(
        AsyncSynthVault vault,
        uint256 userMax,
        bytes memory data
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _requestDepositInVaults(vault, users[i].addr, data);
        }
    }

    function usersRequestRedeem(
        AsyncSynthVault vault,
        uint256 userMax
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _requestRedeemInVault(vault, users[i].addr);
        }
    }

    function usersRequestRedeem(
        AsyncSynthVault vault,
        uint256 userMax,
        bytes memory data
    )
        internal
    {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _requestRedeemInVaults(vault, users[i].addr, data);
        }
    }

    function usersDealApprove(IERC4626 vault, uint256 userMax) internal {
        userMax = userMax > users.length ? users.length : userMax;
        uint256 amount = 0;
        address underlying = address(vault.asset());
        if (underlying == address(WSTETH)) {
            amount = 100 * 10 ** WSTETH.decimals();
        } else if (underlying == address(WBTC)) {
            amount = 10 * 10 ** WBTC.decimals();
        } else if (underlying == address(USDC)) {
            amount = 1_000_000 * 10 ** USDC.decimals();
        }
        for (uint256 i = 0; i < userMax; i++) {
            deal(users[i].addr, type(uint256).max);
            approveVault(vault, users[i]);
            _dealAsset(address(vault.asset()), users[i].addr, amount);
        }
    }

    function approveVault(IERC4626 vault, VmSafe.Wallet memory user) internal {
        vm.startPrank(user.addr);
        IERC20 asset = IERC20(vault.asset());
        asset.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _depositInVault(IERC4626 vault, address owner) internal {
        vm.startPrank(owner);
        IERC20 underlying = IERC20(vault.asset());
        uint256 depositAmount = underlying.balanceOf(owner) / 4;
        vault.deposit(depositAmount, owner);
        vm.stopPrank();
    }

    function _requestDepositInVaults(
        AsyncSynthVault vault,
        address owner
    )
        internal
    {
        vm.startPrank(owner);
        IERC20 asset = IERC20(vault.asset());
        console.log("Deposit request amount:", asset.balanceOf(owner) / 4);
        vaultTested.requestDeposit(asset.balanceOf(owner) / 4, owner, owner, "");
        vm.stopPrank();
    }

    function _requestDepositInVaults(
        AsyncSynthVault vault,
        address owner,
        bytes memory data
    )
        internal
    {
        vm.startPrank(owner);
        IERC20 asset = IERC20(vault.asset());
        vault.requestDeposit(asset.balanceOf(owner) / 4, owner, owner, data);
        vm.stopPrank();
    }

    function _requestRedeemInVaults(
        AsyncSynthVault vault,
        address owner,
        bytes memory data
    )
        internal
    {
        vm.startPrank(owner);
        vault.requestRedeem(vault.balanceOf(owner) / 4, owner, owner, data);
        vm.stopPrank();
    }

    function _requestRedeemInVault(
        AsyncSynthVault vault,
        address owner
    )
        internal
    {
        vm.startPrank(owner);
        console.log("Redeem request amount", vault.balanceOf(owner));
        vault.requestRedeem(vault.balanceOf(owner), owner, owner, "");
        vm.stopPrank();
    }
}
