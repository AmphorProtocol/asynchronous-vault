//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Events } from "../Events.sol";
import { Constants } from "../Constants.sol";
import { IERC7540 } from "../../../src/interfaces/IERC7540.sol";

import "forge-std/console.sol"; //todo remove

abstract contract EventsAssertions is Test, Constants, Events {
    // ERC20 EVENTS

    function assertTransferEvent(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    )
        public
    {
        vm.expectEmit(address(token));
        emit Transfer(from, to, amount);
    }

    function assertApprovalEvent(
        IERC20 token,
        address owner,
        address spender,
        uint256 amount
    )
        public
    {
        vm.expectEmit(address(token));
        emit Approval(owner, spender, amount);
    }

    // ERC4626 EVENTS
    function assertDepositEvent(
        IERC4626 vault,
        address sender,
        address receiver,
        uint256 assets,
        uint256 shares
    )
        public
    {
        vm.expectEmit(address(vault));
        emit Deposit(sender, receiver, assets, shares);
    }

    function assertWithdrawEvent(
        IERC4626 vault,
        address receiver,
        address owner,
        address sender,
        uint256 assets,
        uint256 shares
    )
        public
    {
        vm.expectEmit(address(vault));
        emit Withdraw(sender, receiver, owner, assets, shares);
    }

    function assertDepositRequestEvent(
        IERC7540 vault,
        address receiver,
        address owner,
        uint256 requestId,
        address sender,
        uint256 assets
    )
        public
    {
        vm.expectEmit(address(vault));
        emit DepositRequest(receiver, owner, requestId, sender, assets);
    }

    function assertRedeemRequestEvent(
        IERC7540 vault,
        address receiver,
        address owner,
        uint256 requestId,
        address sender,
        uint256 shares
    )
        public
    {
        vm.expectEmit(address(vault));
        emit RedeemRequest(receiver, owner, requestId, sender, shares);
    }

    function assertEpochEndEvent(
        IERC4626 vault,
        uint256 timestamp,
        uint256 lastSavedBalance,
        uint256 assetsReturned,
        uint256 fees,
        uint256 totalSupply
    )
        public
    {
        vm.expectEmit(address(vault));
        emit EpochEnd(
            timestamp, lastSavedBalance, assetsReturned, fees, totalSupply
        );
    }

    // event EpochStart(
    //     uint256 indexed timestamp, uint256 lastSavedBalance, uint256
    // totalShares
    // );

    function assertEpochStartEvent(
        IERC4626 vault,
        uint256 timestamp,
        uint256 lastSavedBalance,
        uint256 totalSupply
    )
        public
    {
        vm.expectEmit(address(vault));
        emit EpochStart(timestamp, lastSavedBalance, totalSupply);
    }

    function assertAsyncDepositEvent(
        IERC4626 vault,
        uint256 requestId,
        uint256 requestedAssets,
        uint256 acceptedAssets
    )
        public
    {
        vm.expectEmit(address(vault));
        emit AsyncDeposit(requestId, requestedAssets, acceptedAssets);
    }

    function assertAsyncWithdrawEvent(
        IERC4626 vault,
        uint256 requestId,
        uint256 requestedShares,
        uint256 acceptedShares
    )
        public
    {
        vm.expectEmit(address(vault));
        emit AsyncWithdraw(requestId, requestedShares, acceptedShares);
    }
}
