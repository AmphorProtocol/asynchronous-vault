//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC7540 } from "../../../src/interfaces/IERC7540.sol";

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { Assertions } from "./Assertions.sol";
import { Constants } from "../Constants.sol";

import { AsyncSynthVault } from "../../../src/AsyncSynthVault.sol";

abstract contract AssertionsRequest is Assertions {
    struct PendingDepositsData {
        uint256 owner;
        uint256 sender;
        uint256 vault;
        uint256 receiver;
    }

    struct PendingRedeemsData {
        uint256 owner;
        uint256 sender;
        uint256 vault;
        uint256 receiver;
    }

    function assertRequestDeposit(
        AsyncSynthVault vault,
        address sender,
        address owner,
        address receiver,
        uint256 assets,
        bytes memory data
    )
        public
    {
        uint256 epochId = vault.epochId();

        // assets data before deposit
        AssetsData memory assetsBefore =
            getAssetsData(vault, sender, owner, receiver);

        // shares data before deposit
        SharesData memory sharesBefore =
            getSharesData(vault, sender, owner, receiver);

        // pending deposits data before deposit
        PendingDepositsData memory pendingDepositsBefore = getPendingDepositData(
            AsyncSynthVault(address(vault)), sender, owner, receiver
        );

        // assertions on events
        assertTransferEvent(
            IERC20(vault.asset()), owner, address(vault), assets
        ); // transfer from owner to vault of its assets
        assertDepositRequestEvent(
            vault, receiver, owner, epochId, sender, assets
        );

        // request deposit //
        vm.prank(sender);
        vault.requestDeposit(assets, receiver, owner, data);

        // total supply should not change
        assertTotalSupply(vault, sharesBefore.totalSupply);

        // totalAssets() should not change
        assertTotalAssets(vault, assetsBefore.totalAssets);

        // assertion on vault asset balance, should increase
        assertVaultAssetBalance(vault, assetsBefore.vault + assets);

        // assertion on shares, should not change
        assertSharesBalance(vault, owner, sharesBefore.owner);
        assertSharesBalance(vault, sender, sharesBefore.sender);
        assertSharesBalance(vault, receiver, sharesBefore.receiver);
        assertSharesBalance(vault, address(vault), sharesBefore.vault);

        // assertion on assets, owner should decrease, receiver should not
        // change
        assertAssetBalance(vault, owner, assetsBefore.owner - assets);
        if (owner != receiver) {
            assertAssetBalance(vault, receiver, assetsBefore.receiver);
        }

        // assertion on pending deposits, only total and receiver should
        // increase
        assertPendingDepositRequest(vault, owner, pendingDepositsBefore.owner);
        assertPendingDepositRequest(vault, sender, pendingDepositsBefore.sender);
        assertPendingDepositRequest(
            vault, receiver, pendingDepositsBefore.receiver + assets
        );
        assertTotalPendingDeposits(vault, pendingDepositsBefore.vault + assets);
    }

    function assertPendingDepositRequest(
        IERC7540 vault,
        address owner,
        uint256 expected
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.pendingDepositRequest(owner),
            expected,
            string.concat(
                userLabel,
                " has wrong pending deposit assets balance in ",
                vaultLabel,
                explanation
            )
        );
    }

    function assertTotalPendingDeposits(
        AsyncSynthVault vault,
        uint256 expected
    )
        public
    {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.totalPendingDeposits(),
            expected,
            string.concat("Total pending deposits in ", vaultLabel, explanation)
        );
    }

    function assertPendingRedeemRequest(
        IERC7540 vault,
        address owner,
        uint256 expected
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.pendingRedeemRequest(owner),
            expected,
            string.concat(
                userLabel,
                " has wrong pending redeem shares balance in ",
                vaultLabel,
                explanation
            )
        );
    }

    function getPendingDepositData(
        AsyncSynthVault vault,
        address sender,
        address owner,
        address receiver
    )
        public
        view
        returns (PendingDepositsData memory)
    {
        return PendingDepositsData({
            sender: vault.pendingDepositRequest(sender),
            owner: vault.pendingDepositRequest(owner),
            receiver: vault.pendingDepositRequest(receiver),
            vault: vault.totalPendingDeposits()
        });
    }

    function getPendingRedeemData(
        AsyncSynthVault vault,
        address sender,
        address owner,
        address receiver
    )
        public
        view
        returns (PendingRedeemsData memory)
    {
        return PendingRedeemsData({
            sender: vault.pendingRedeemRequest(sender),
            owner: vault.pendingRedeemRequest(owner),
            receiver: vault.pendingRedeemRequest(receiver),
            vault: vault.totalPendingRedeems()
        });
    }
}