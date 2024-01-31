//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Assertions } from "./utils/Assertions.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { SynthVaultPermit, SynthVault } from "../../src/SynthVaultPermit.sol";
import { VmSafe } from "forge-std/Vm.sol";

contract TestBase is Constants, Events, Assertions {
    // OWNER ACTIONS //
    function open(SynthVault vault, int256 performanceInBips) public {
        vm.assume(performanceInBips > -10_000 && performanceInBips < 10_000);
        performanceInBips = performanceInBips;
        address owner = vault.owner();
        deal(owner, type(uint256).max);
        _dealAssets(owner);
        _approveVaults(owner);
        vm.startPrank(owner);
        int256 lastAssetAmount = int256(vault.totalAssets());
        int256 performance = lastAssetAmount * performanceInBips;
        int256 toSendBack = performance / bipsDivider + lastAssetAmount;
        vault.open(uint256(toSendBack));
        vm.stopPrank();
    }

    function close(SynthVault vault) public {
        address owner = vault.owner();
        vm.prank(owner);
        vault.close();
    }

    function pause(SynthVault vault) public {
        address owner = vault.owner();
        vm.prank(owner);
        vault.pause();
    }

    function unpause(SynthVault vault) public {
        address owner = vault.owner();
        vm.prank(owner);
        vault.unpause();
    }

    // USERS ACTIONS //

    function mint(SynthVault vault, VmSafe.Wallet memory user) public {
        mint(vault, user, USDC.balanceOf(user.addr));
    }

    function deposit(SynthVault vault, VmSafe.Wallet memory user) public {
        deposit(vault, user, USDC.balanceOf(user.addr));
    }

    function withdraw(SynthVault vault, VmSafe.Wallet memory user) public {
        withdraw(vault, user, USDC.balanceOf(user.addr));
    }

    function redeem(SynthVault vault, VmSafe.Wallet memory user) public {
        redeem(vault, user, vault.balanceOf(user.addr));
    }

    function mint(
        SynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        public
    {
        vm.startPrank(user.addr);
        vault.mint(amount, user.addr);
    }

    function deposit(
        SynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        public
    {
        vm.startPrank(user.addr);
        vault.deposit(amount, user.addr);
    }

    function withdraw(
        SynthVault vault,
        VmSafe.Wallet memory user,
        uint256 amount
    )
        public
    {
        vm.startPrank(user.addr);
        vault.withdraw(amount, user.addr, user.addr);
    }

    function redeem(
        SynthVault vault,
        VmSafe.Wallet memory user,
        uint256 shares
    )
        public
    {
        vm.startPrank(user.addr);
        vault.redeem(shares, user.addr, user.addr);
    }

    // USERS CONFIGURATION //

    function usersDealApproveAndDeposit(uint256 userMax) public {
        userMax = userMax > users.length ? users.length : userMax;
        usersDealApprove(userMax);
        usersDeposit(userMax);
    }

    function usersDeposit(uint256 userMax) public {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _depositInVaults(users[i].addr);
        }
    }

    function usersDealApprove(uint256 userMax) public {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            deal(users[i].addr, type(uint256).max);
            _approveVaults(users[i].addr);
            _dealAssets(users[i].addr);
        }
    }

    function _approveVaults(address owner) internal {
        vm.startPrank(owner);
        USDC.approve(address(vaultUSDC), type(uint256).max);
        WSTETH.approve(address(vaultWSTETH), type(uint256).max);
        WBTC.approve(address(vaultWBTC), type(uint256).max);
        vm.stopPrank();
    }

    function _dealAssets(address owner) internal {
        vm.startPrank(USDC_WHALE);
        USDC.transfer(owner, 1000 * 10 ** USDC.decimals());
        vm.stopPrank();
        deal(address(WSTETH), owner, 100 * 10 ** WSTETH.decimals());
        deal(address(WBTC), owner, 10 * 10 ** WBTC.decimals());
    }

    function _depositInVaults(address owner) internal {
        vm.startPrank(owner);
        uint256 usdcDeposit = USDC.balanceOf(owner) / 4;
        vaultUSDC.deposit(usdcDeposit, owner);
        uint256 wstethDeposit = WSTETH.balanceOf(owner) / 4;
        vaultWSTETH.deposit(wstethDeposit, owner);
        uint256 wbtcDeposit = WBTC.balanceOf(owner) / 4;
        vaultWBTC.deposit(wbtcDeposit, owner);
        vm.stopPrank();
    }
}
