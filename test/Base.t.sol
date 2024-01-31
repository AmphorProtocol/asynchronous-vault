//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Assertions } from "./utils/Assertions.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

contract TestBase is Constants, Events, Assertions {
    function test() public { }

    function usersDealApprove(uint256 userMax) public {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _approveVaults(users[i].addr);
            _dealAssets(users[i].addr);
            deal(users[i].addr, type(uint256).max);
        }
    }

    function usersDealApproveAndDeposit(uint256 userMax) public {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _approveVaults(users[i].addr);
            _dealAssets(users[i].addr);
            deal(users[i].addr, type(uint256).max);
            _depositInVaults(users[i].addr);
        }
    }

    function usersDeposit(uint256 userMax) public {
        userMax = userMax > users.length ? users.length : userMax;
        for (uint256 i = 0; i < userMax; i++) {
            _depositInVaults(users[i].addr);
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
        deal(address(USDC), owner, 1000 * 10 ** USDC.decimals());
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
