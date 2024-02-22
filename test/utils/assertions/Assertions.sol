//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { AsyncSynthVault } from "../../../src/AsyncSynthVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { EventsAssertions } from "./EventsAssertions.sol";
import { Constants } from "../Constants.sol";
import { AsyncSynthVault } from "../../../src/AsyncSynthVault.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { console } from "forge-std/console.sol";

abstract contract Assertions is EventsAssertions {
    using Math for uint256;
    // Struct for assets data of owner,receiver and vault

    struct AssetsData {
        uint256 owner;
        uint256 sender;
        uint256 vault;
        uint256 totalAssets;
        uint256 receiver;
    }

    // Struct for shares data of owner,receiver and vault
    struct SharesData {
        uint256 owner;
        uint256 sender;
        uint256 vault;
        uint256 receiver;
        uint256 totalSupply;
    }

    // Struct for shares value in assets of owner and receiver
    struct SharesValueData {
        uint256 owner;
        uint256 sender;
        uint256 receiver;
    }

    function assertDeposit(
        IERC4626 vault,
        address owner,
        address receiver,
        uint256 assets
    )
        public
    {
        // assets data before deposit
        AssetsData memory assetsBefore =
            getAssetsData(vault, owner, owner, receiver);

        // shares data before deposit
        SharesData memory sharesBefore =
            getSharesData(vault, owner, owner, receiver);

        // shares value in assets before deposit
        SharesValueData memory sharesValueBeforeDep =
            getSharesValueData(vault, owner, owner, receiver);

        // expected shares after deposit
        uint256 previewedShares = vault.previewDeposit(assets);

        // assertions on events
        assertTransferEvent(
            IERC20(vault.asset()), owner, address(vault), assets
        ); // transfer from owner to vault of its assets
        assertTransferEvent(vault, address(0), receiver, previewedShares); // transfer
            // from vault to receiver of its shares
        assertDepositEvent(vault, owner, receiver, assets, previewedShares); // deposit
            // event

        // deposit //
        vm.prank(owner);
        uint256 depositReturn = vault.deposit(assets, receiver);

        // first check this to simplify the rest of the assertions
        assertEq(
            depositReturn,
            previewedShares,
            "Deposit return is not equal to previewDeposit return"
        );

        // assertion on total supply
        assertTotalSupply(vault, sharesBefore.totalSupply + depositReturn);

        // assertion on total assets
        assertTotalAssets(vault, assetsBefore.totalAssets + assets);
        assertVaultAssetBalance(vault, assetsBefore.vault + assets);

        // assertion on shares
        if (owner != receiver) {
            assertSharesBalance(vault, owner, sharesBefore.owner);
        }
        assertSharesBalance(
            vault, receiver, sharesBefore.receiver + previewedShares
        );
        assertSharesBalance(vault, address(vault), sharesBefore.vault);

        // assertion on assets
        assertAssetBalance(vault, owner, assetsBefore.owner - assets);
        if (owner != receiver) {
            assertAssetBalance(vault, receiver, assetsBefore.receiver);
        }

        // assertion on shares value in assets
        assertSharesValueInAssets(
            vault, receiver, sharesValueBeforeDep.receiver + assets
        );
    }

    function assertMint(
        IERC4626 vault,
        address owner,
        address receiver,
        uint256 shares
    )
        public
    {
        // assets data before deposit
        AssetsData memory assetsBefore =
            getAssetsData(vault, owner, owner, receiver);

        // shares data before deposit
        SharesData memory sharesBefore =
            getSharesData(vault, owner, owner, receiver);

        // shares value in assets before deposit
        SharesValueData memory sharesValueBefore =
            getSharesValueData(vault, owner, owner, receiver);

        // expected assets after deposit
        uint256 previewedAssets = vault.previewMint(shares);

        // assertions on events
        assertTransferEvent(
            IERC20(vault.asset()), owner, address(vault), previewedAssets
        ); // transfer from owner to vault of its assets
        assertTransferEvent(vault, address(0), receiver, shares); // transfer
            // from vault to receiver of its shares
        assertDepositEvent(vault, owner, receiver, previewedAssets, shares); // deposit
            // event

        // mint //
        vm.prank(owner);
        uint256 mintReturn = vault.mint(shares, receiver);

        // first check this to simplify the rest of the assertions
        assertEq(
            mintReturn,
            previewedAssets,
            "Mint return is not equal to previewMint return"
        );

        // assertion on total supply
        assertTotalSupply(vault, sharesBefore.totalSupply + shares);

        // assertion on total assets
        assertTotalAssets(vault, assetsBefore.totalAssets + previewedAssets);
        assertVaultAssetBalance(vault, assetsBefore.vault + previewedAssets);

        // assertion on shares
        assertSharesBalance(vault, receiver, sharesBefore.receiver + shares);
        if (owner != receiver) {
            assertSharesBalance(vault, owner, sharesBefore.owner);
        }
        assertSharesBalance(vault, address(vault), sharesBefore.vault);

        // assertion on assets
        assertAssetBalance(vault, owner, assetsBefore.owner - previewedAssets);
        if (owner != receiver) {
            assertAssetBalance(vault, receiver, assetsBefore.receiver);
        }

        // assertion on shares value in assets
        assertSharesValueInAssets(
            vault, receiver, sharesValueBefore.receiver + mintReturn
        );
    }

    function assertWithdraw(
        IERC4626 vault,
        address sender,
        address owner,
        address receiver,
        uint256 assets
    )
        public
    {
        // assets data before withdraw
        AssetsData memory assetsBefore =
            getAssetsData(vault, sender, owner, receiver);

        // shares data before withdraw
        SharesData memory sharesBefore =
            getSharesData(vault, sender, owner, receiver);

        // shares value in assets before withdraw
        SharesValueData memory sharesValueBefore =
            getSharesValueData(vault, owner, owner, receiver);

        // expected shares after withdraw
        uint256 previewedShares = vault.previewWithdraw(assets);

        // assertions on events
        assertTransferEvent(
            IERC20(vault.asset()), address(vault), receiver, assets
        ); // transfer from owner to vault of its assets
        assertTransferEvent(vault, owner, address(0), previewedShares); // transfer
            // from vault to receiver of its shares
        assertWithdrawEvent(
            vault, sender, owner, receiver, assets, previewedShares
        );

        // mint //
        vm.prank(sender);
        uint256 withdrawReturn = vault.withdraw(assets, receiver, owner);

        // first check this to simplify the rest of the assertions
        assertEq(
            withdrawReturn,
            previewedShares,
            "Withdraw return is not equal to previewWithdraw return"
        );

        // assertion on total supply
        assertTotalSupply(vault, sharesBefore.totalSupply - previewedShares);

        // assertion on total assets
        assertTotalAssets(vault, assetsBefore.totalAssets - assets);
        assertVaultAssetBalance(vault, assetsBefore.vault - assets);

        // assertion on shares
        assertSharesBalance(vault, owner, sharesBefore.owner - previewedShares);
        if (owner != receiver) {
            assertSharesBalance(vault, receiver, sharesBefore.receiver);
        }
        if (sender != owner) {
            assertSharesBalance(vault, sender, sharesBefore.sender);
        }
        assertSharesBalance(vault, address(vault), sharesBefore.vault);

        // assertion on assets
        assertAssetBalance(vault, receiver, assetsBefore.receiver + assets);
        if (owner != receiver) {
            assertAssetBalance(vault, owner, assetsBefore.owner);
        }
        if (sender != owner) {
            assertAssetBalance(vault, sender, assetsBefore.sender);
        }

        // assertion on shares value in assets
        assertSharesValueInAssets(
            vault, receiver, sharesValueBefore.receiver + assets
        );
    }

    function assertRedeem(
        IERC4626 vault,
        address sender,
        address owner,
        address receiver,
        uint256 shares
    )
        public
    {
        // assets data before redeem
        AssetsData memory assetsBefore =
            getAssetsData(vault, owner, owner, receiver);

        // shares data before redeem
        SharesData memory sharesBefore =
            getSharesData(vault, owner, owner, receiver);

        // shares value in assets before redeem
        SharesValueData memory sharesValueBefore =
            getSharesValueData(vault, sender, owner, receiver);

        // expected shares after redeem
        uint256 previewedAssets = vault.previewRedeem(shares);

        // assertions on events
        assertTransferEvent(
            IERC20(vault.asset()), address(vault), receiver, previewedAssets
        ); // transfer from owner to vault of its assets
        assertTransferEvent(vault, owner, address(0), shares); // transfer
            // from vault to receiver of its shares
        assertWithdrawEvent(
            vault, sender, owner, receiver, previewedAssets, shares
        );

        // mint //
        vm.prank(sender);
        uint256 redeemReturn = vault.redeem(shares, receiver, owner);

        // first check this to simplify the rest of the assertions
        assertEq(
            redeemReturn,
            previewedAssets,
            "Redeem return is not equal to previewRedeem return"
        );

        // assertion on total supply
        assertTotalSupply(vault, sharesBefore.totalSupply - shares);

        // assertion on total assets
        assertTotalAssets(vault, assetsBefore.totalAssets - previewedAssets);
        assertVaultAssetBalance(vault, assetsBefore.vault - previewedAssets);

        // assertion on shares
        assertSharesBalance(vault, owner, sharesBefore.owner - shares);
        if (receiver != owner) {
            assertSharesBalance(vault, receiver, sharesBefore.receiver);
        }
        if (sender != owner) {
            assertSharesBalance(vault, sender, sharesBefore.sender);
        }
        assertSharesBalance(vault, address(vault), sharesBefore.vault);

        // assertion on assets
        assertAssetBalance(
            vault, receiver, assetsBefore.receiver + previewedAssets
        );
        if (receiver != owner) {
            assertAssetBalance(vault, owner, assetsBefore.owner);
        }
        if (sender != owner) {
            assertAssetBalance(vault, sender, assetsBefore.sender);
        }

        // assertion on shares value in assets
        assertSharesValueInAssets(
            vault, receiver, sharesValueBefore.receiver + previewedAssets
        );
    }

    function getAssetsData(
        IERC4626 vault,
        address sender,
        address owner,
        address receiver
    )
        public
        view
        returns (AssetsData memory)
    {
        return AssetsData({
            vault: IERC20(vault.asset()).balanceOf(address(vault)),
            sender: IERC20(vault.asset()).balanceOf(sender),
            owner: IERC20(vault.asset()).balanceOf(owner),
            totalAssets: vault.totalAssets(),
            receiver: IERC20(vault.asset()).balanceOf(receiver)
        });
    }

    function getSharesData(
        IERC4626 vault,
        address sender,
        address owner,
        address receiver
    )
        public
        view
        returns (SharesData memory)
    {
        return SharesData({
            owner: vault.balanceOf(owner),
            sender: vault.balanceOf(sender),
            vault: vault.balanceOf(address(vault)),
            receiver: vault.balanceOf(receiver),
            totalSupply: vault.totalSupply()
        });
    }

    struct VaultState {
        uint256 lastSavedBalance;
        uint256 feeInBps;
        uint256 vaultBalance;
        uint256 totalSupply;
        uint256 totalAssets;
        uint256 pendingDeposit;
        uint256 pendingRedeem;
        uint256 claimableShares;
        uint256 claimableAssets;
    }

    function getVaultState(AsyncSynthVault vault)
        public
        view
        returns (VaultState memory)
    {
        uint256 lastSavedBalance = vault.totalAssets();
        uint256 feeInBps = vault.feeInBps();

        uint256 vaultBalance = IERC20(vault.asset()).balanceOf(address(vault));

        // vault totalSupply and totalAssets before open
        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();

        // amount of pending deposits and redeems
        uint256 pendingDeposit = vault.totalPendingDeposits();
        uint256 pendingRedeem = vault.totalPendingRedeems();

        //  amount of claimable shares and assets before open
        uint256 claimableShares = vault.totalClaimableDeposits();
        uint256 claimableAssets = vault.totalClaimableRedeems();

        return VaultState({
            lastSavedBalance: lastSavedBalance,
            feeInBps: feeInBps,
            vaultBalance: vaultBalance,
            totalSupply: totalSupply,
            totalAssets: totalAssets,
            pendingDeposit: pendingDeposit,
            pendingRedeem: pendingRedeem,
            claimableShares: claimableShares,
            claimableAssets: claimableAssets
        });
    }

    function getSharesValueData(
        IERC4626 vault,
        address sender,
        address owner,
        address receiver
    )
        public
        view
        returns (SharesValueData memory)
    {
        return SharesValueData({
            owner: vault.convertToAssets(vault.balanceOf(owner)),
            sender: vault.convertToAssets(vault.balanceOf(sender)),
            receiver: vault.convertToAssets(vault.balanceOf(receiver))
        });
    }

    // END AND START OF EPOCH
    function assertIsInGrossProfit(
        IERC4626 vault,
        address owner,
        uint256 deposited
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation =
            " | Current (left) < Deposited value (right)";
        assertGt(
            vault.convertToAssets(vault.balanceOf(owner)),
            deposited,
            string.concat(userLabel, " is in loss in ", vaultLabel, explanation)
        );
    }

    function assertOpen(
        AsyncSynthVault vault,
        int256 performanceInBps
    )
        public
    {
        console.log("vaultusdc", address(vault));
        VaultState memory stateBefore = getVaultState(vault);
        // expected shares and assets to mint and withdraw when request are
        // executed
        uint256 expectedSharesToMint =
            vault.previewDeposit(stateBefore.pendingDeposit);
        uint256 expectedAssetsToWithdraw =
            vault.previewRedeem(stateBefore.pendingRedeem);
        // expected asset returned
        uint256 assetReturned = performanceToAssets(
            int256(stateBefore.lastSavedBalance), performanceInBps
        );
        console.log(uint256(int256(stateBefore.lastSavedBalance)));

        // // Request management
        // assertDepositEvent(
        //     vault,
        //     address(vault),
        //     address(vault),
        //     stateBefore.pendingDeposit,
        //     expectedSharesToMint
        // );
        // assertWithdrawEvent(
        //     vault,
        //     address(vault),
        //     address(vault),
        //     address(vault),
        //     stateBefore.pendingRedeem,
        //     expectedAssetsToWithdraw
        // );

        // assertEpochEndEvent(
        //     vault,
        //     block.timestamp,
        //     stateBefore.lastSavedBalance,
        //     assetReturned,
        //     expectedFees,
        //     vault.totalSupply()
        // );
        uint256 expectedFees;
        if (
            assetReturned > stateBefore.lastSavedBalance
                && stateBefore.feeInBps > 0
        ) {
            uint256 profits;
            unchecked {
                profits = assetReturned - stateBefore.lastSavedBalance;
            }
            expectedFees = (profits).mulDiv(
                stateBefore.feeInBps, 10_000, Math.Rounding.Ceil
            );
        }

        // open

        open(vault, performanceInBps);

        // it should set isOpen to true
        assertEq(vault.isOpen(), true, "Vault is not open");

        // amount of claimable shares and assets should increase
        assertEq(
            vault.totalClaimableDeposits(),
            stateBefore.claimableShares + expectedSharesToMint,
            "Claimable shares is not correct"
        );

        assertEq(
            vault.totalClaimableRedeems(),
            stateBefore.claimableAssets + expectedAssetsToWithdraw,
            "Claimable assets is not correct"
        );

        //amount of pending deposits and redeems should be 0
        assertEq(vault.totalPendingDeposits(), 0, "Pending deposits is not 0");
        assertEq(vault.totalPendingRedeems(), 0, "Pending redeems is not 0");

        // totalSupply should be equal to totalSupplyBefore +
        // expectedSharesToMint - pendingRedeem
        assertTotalSupply(
            vault,
            stateBefore.totalSupply + expectedSharesToMint
                - stateBefore.pendingRedeem
        );

        assertTotalAssets(
            vault,
            assetReturned - expectedFees - expectedAssetsToWithdraw
                + stateBefore.pendingDeposit
        );

        // vault balance in assets should increase by assetReturned -
        // expectedFees + pendingDeposit
        assertVaultAssetBalance(
            vault, assetReturned - expectedFees + stateBefore.pendingDeposit
        );
    }

    function performanceToAssets(
        int256 lastAssetAmount,
        int256 performanceInBips
    )
        public
        pure
        returns (uint256)
    {
        int256 performance = lastAssetAmount * performanceInBips;
        int256 toSendBack = performance / bipsDivider + lastAssetAmount;
        return uint256(toSendBack);
    }

    function open(AsyncSynthVault vault, int256 performanceInBips) public {
        vm.assume(performanceInBips > -10_000 && performanceInBips < 10_000);
        uint256 lastSavedBalance = vault.totalAssets();
        uint256 toSendBack = uint256(
            performanceToAssets(int256(lastSavedBalance), performanceInBips)
        );
        address owner = vault.owner();
        deal(owner, type(uint256).max);
        vm.startPrank(owner);
        SafeERC20.forceApprove(
            IERC20(vault.asset()), address(vault), type(uint256).max
        );
        vm.stopPrank();
        _dealAsset(vault.asset(), owner, toSendBack);
        vm.prank(owner);
        vault.open(toSendBack);
    }

    function _dealAsset(address asset, address owner, uint256 amount) public {
        if (asset == address(USDC)) {
            vm.startPrank(USDC_WHALE);
            USDC.transfer(owner, amount);
            vm.stopPrank();
        } else {
            deal(asset, owner, amount);
        }
    }

    // it should verify totalAssets == totalsAssetsBefore - assetsToRedeem +
    // pendingDeposit
    // it should verify totalSupply == totalSupplyBefore +
    // previewDeposit(pendingDeposit) - pendingRedeem

    function assertIsInLoss(
        IERC4626 vault,
        address owner,
        uint256 deposited
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation =
            " | Current (left) > Deposited value (right)";
        assertLt(
            vault.convertToAssets(vault.balanceOf(owner)),
            deposited,
            string.concat(
                userLabel, " is in profit in ", vaultLabel, explanation
            )
        );
    }

    // SHARES

    function assertSharesBalance(
        IERC4626 vault,
        address owner,
        uint256 expected
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.balanceOf(owner),
            expected,
            string.concat(
                userLabel,
                " has wrong shares balance in ",
                vaultLabel,
                explanation
            )
        );
    }

    function assertTotalSupply(IERC4626 vault, uint256 expected) public {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.totalSupply(),
            expected,
            string.concat("Total shares supply in ", vaultLabel, explanation)
        );
    }

    // ASSETS

    function assertAssetBalance(
        IERC4626 vault,
        address owner,
        uint256 expected
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            IERC20(vault.asset()).balanceOf(owner),
            expected,
            string.concat(
                userLabel,
                " has wrong asset balance in ",
                vaultLabel,
                explanation
            )
        );
    }

    function assertSharesValueInAssets(
        IERC4626 vault,
        address owner,
        uint256 expected
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.convertToAssets(vault.balanceOf(owner)),
            expected,
            string.concat(
                userLabel,
                " has wrong shares value in assets in ",
                vaultLabel,
                explanation
            )
        );
    }

    function assertTotalAssets(IERC4626 vault, uint256 expected) public {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.totalAssets(),
            expected,
            string.concat("Total assets in ", vaultLabel, explanation)
        );
    }

    function assertVaultAssetBalance(IERC4626 vault, uint256 expected) public {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            IERC20(vault.asset()).balanceOf(address(vault)),
            expected,
            string.concat(
                "Vault balance in assets in ", vaultLabel, explanation
            )
        );
    }

    function assertVaultSharesBalance(
        IERC4626 vault,
        uint256 expected
    )
        public
    {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.balanceOf(address(vault)),
            expected,
            string.concat(
                "Vault balance in assets in ", vaultLabel, explanation
            )
        );
    }

    function assertDecreaseDeposit(AsyncSynthVault vault, address receiver) internal {
        // it should decrease of assets the deposit request balance of owner
        // it should decrease of assets the vault underlying balance
        // it should increase of assets the receiver underlying balance
        // it should emit `DepositRequestDecreased` event -> todo
        uint256 ownerDepRequestBalance = vault.pendingDepositRequest(user1.addr);
        uint256 ownerDecreaseAmount = ownerDepRequestBalance/2;
        uint256 finalOwnerDepRequestBalance = ownerDepRequestBalance - ownerDecreaseAmount;
        uint256 vaultUnderlyingBalanceBef = IERC20(vault.asset()).balanceOf(address(vault));
        uint256 user2UnderlyingBalanceBef = IERC20(vault.asset()).balanceOf(receiver);
        vm.startPrank(user1.addr);
        vault.decreaseRedeemRequest(
            ownerDecreaseAmount,
            user2.addr
        );
        vm.stopPrank();
        assertEq(vault.pendingDepositRequest(user1.addr), finalOwnerDepRequestBalance);
        assertEq(IERC20(vault.asset()).balanceOf(address(vault)), vaultUnderlyingBalanceBef - ownerDecreaseAmount);
        assertEq(IERC20(vault.asset()).balanceOf(receiver), user2UnderlyingBalanceBef + ownerDecreaseAmount);
    }
}
