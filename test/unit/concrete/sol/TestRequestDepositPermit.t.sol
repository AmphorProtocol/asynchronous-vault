// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { TestBase } from "../../../Base.t.sol";
import { PermitParams, SyncSynthVault } from "@src/SyncSynthVault.sol";
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
                SyncSynthVault.ERC4626ExceededMaxDeposit.selector,
                user1.addr,
                1,
                0
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

    //     function test_depositWithPermitMinShares() public {
    //         uint256 underlying = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         uint256 previewShares = _synthVault.previewMint(underlying);
    //         vm.prank(_user);
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         _synthVault.depositWithPermitMinShares(
    //             underlying, _user, previewShares, params
    //         );
    //     }

    //     function test_depositWithPermitMinSharesUintMax() public {
    //         uint256 underlying = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), UINT256_MAX, _usdc.nonces(_user),
    // _deadline
    //         );
    //         uint256 previewShares = _synthVault.previewMint(underlying);
    //         vm.prank(_user);
    //         PermitParams memory params = PermitParams({
    //             value: UINT256_MAX,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         _synthVault.depositWithPermitMinShares(
    //             underlying, _user, previewShares, params
    //         );

    //         assert(
    //             ERC20(_underlying).allowance(_user, address(_synthVault))
    //                 == UINT256_MAX - underlying
    //         );
    //     }

    //     function test_depositWithPermitMinSharesTooLow() public {
    //         uint256 underlying = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         uint256 previewShares = _synthVault.previewMint(underlying);
    //         vm.prank(_user);
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         _synthVault.depositWithPermitMinShares(
    //             underlying, _user, previewShares + 1, params
    //         );
    //     }

    //     function test_MintWithPermit() public {
    //         uint256 sharesExpected = 1_000_000 * 10 ** _decimalOffset;
    //         uint256 underlying = _synthVault.previewMint(sharesExpected);
    //         uint256 underlyingBefore = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         _synthVault.mintWithPermit(sharesExpected, _user, params);
    //         assertSharesBalance(_user, sharesExpected);
    //         assertUnderlyingBalance(_user, underlyingBefore - underlying);
    //     }

    //     function test_MintWithPermitAfterOtherUserDeposit() public {
    //         address otherUser = address(0x012345);
    //         giveEthUnderlyingAndApprove(otherUser);
    //         vm.prank(otherUser);
    //         _synthVault.deposit(1000 * 10 ** 6, otherUser);
    //         uint256 sharesExpected = 1_000_000 * 10 ** _decimalOffset;
    //         uint256 underlying = _synthVault.previewMint(sharesExpected);
    //         uint256 underlyingBefore = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         _synthVault.mintWithPermit(sharesExpected, _user, params);
    //         assertSharesBalance(_user, sharesExpected);
    //         assertUnderlyingBalance(_user, underlyingBefore - underlying);
    //     }

    //     function test_MintWithPermitAfterVaultProfit() public {
    //         // First deposit
    //         address otherUser = address(0x012345);
    //         giveEthUnderlyingAndApprove(otherUser);
    //         vm.prank(otherUser);
    //         _synthVault.deposit(1000 * 10 ** 6, otherUser);

    //         // Vault profit
    //         deal(
    //             address(_usdc),
    //             address(_synthVault),
    //             _usdc.balanceOf(address(_synthVault)) + 100
    //         );

    //         // Mint with permit
    //         uint256 sharesExpected = 1_000_000 * 10 ** _decimalOffset;
    //         uint256 underlying = _synthVault.previewMint(sharesExpected);
    //         uint256 underlyingBefore = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         _synthVault.mintWithPermit(sharesExpected, _user, params);
    //         assertSharesBalance(_user, sharesExpected);
    //         assertUnderlyingBalance(_user, underlyingBefore - underlying);
    //     }

    //     function test_MintWithPermitTooMuch() public {
    //         uint256 sharesExpected = 1_000_000 * 10 ** _decimalOffset;
    //         uint256 underlying = _synthVault.previewMint(sharesExpected);
    //         uint256 tooMuchUnderlying =
    // _synthVault.previewMint(sharesExpected * 10);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );

    //         PermitParams memory params = PermitParams({
    //             value: tooMuchUnderlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         vm.expectRevert("EIP2612: invalid signature");
    //         _synthVault.mintWithPermit(sharesExpected * 10, _user, params);
    //     }

    //     function test_TryingToScamPermit() public {
    //         uint256 underlying = _getUnderlyingBalance(_user);
    //         address _spender = address(_synthVault);
    //         (uint8 v, bytes32 r, bytes32 s) =
    //             _signPermit(_spender, underlying, _usdc.nonces(_user),
    // _deadline);
    //         address randomSpender = vm.addr(0x1234);
    //         vm.expectRevert("EIP2612: invalid signature");
    //         _usdc.permit(_user, randomSpender, underlying, _deadline, v, r,
    // s);
    //     }

    //     function test_mintWithPermitAfterStart() public {
    //         giveEthUnderlyingAndApprove(_user);
    //         _synthVault.start();
    //         uint256 sharesAmount = 100 * 10 ** 18;
    //         uint256 assetAmount = _synthVault.previewMint(sharesAmount);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), assetAmount, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: assetAmount,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         vm.expectRevert(
    //             abi.encodeWithSelector(
    //                 AmphorSyntheticVault.ERC4626ExceededMaxMint.selector,
    //                 _user,
    //                 sharesAmount,
    //                 0
    //             )
    //         );
    //         _synthVault.mintWithPermit(sharesAmount, _user, params);
    //     }

    //     function test_depositWithPermitAfterStart() public {
    //         giveEthUnderlyingAndApprove(_user);
    //         _synthVault.start();
    //         uint256 assetAmount = 100 * 10 ** 18;
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), assetAmount, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: assetAmount,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         vm.expectRevert(
    //             abi.encodeWithSelector(
    //                 AmphorSyntheticVault.ERC4626ExceededMaxDeposit.selector,
    //                 _user,
    //                 assetAmount,
    //                 0
    //             )
    //         );
    //         _synthVault.depositWithPermit(assetAmount, _user, params);
    //     }

    //     function test_MintWithPermitMaxAssets() public {
    //         uint256 sharesExpected = 1000 * 10 ** _synthVault.decimals();
    //         uint256 underlying = _synthVault.previewMint(sharesExpected);
    //         uint256 underlyingBefore = _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         _synthVault.mintWithPermitMaxAssets(
    //             sharesExpected, _user, underlying, params
    //         );
    //         assertSharesBalance(_user, sharesExpected);
    //         assertUnderlyingBalance(_user, underlyingBefore - underlying);
    //     }

    //     function test_MintWithPermitMaxAssetsTooMuch() public {
    //         uint256 sharesExpected = 1000 * 10 ** _synthVault.decimals();
    //         uint256 underlying = _synthVault.previewMint(sharesExpected);
    //         _getUnderlyingBalance(_user);
    //         (uint8 v, bytes32 r, bytes32 s) = _signPermit(
    //             address(_synthVault), underlying, _usdc.nonces(_user),
    // _deadline
    //         );
    //         PermitParams memory params = PermitParams({
    //             value: underlying,
    //             deadline: _deadline,
    //             v: v,
    //             r: r,
    //             s: s
    //         });
    //         vm.prank(_user);
    //         vm.expectRevert(
    //             abi.encodeWithSelector(
    //                 AmphorSyntheticVault.ERC4626TooMuchAssetsDeposited.selector,
    //                 _user,
    //                 underlying,
    //                 underlying - 1
    //             )
    //         );
    //         _synthVault.mintWithPermitMaxAssets(
    //             sharesExpected, _user, underlying - 1, params
    //         );
    //     }

    //     function _execute_permit(address _spender, uint256 _value) private {
    //         (uint8 v, bytes32 r, bytes32 s) =
    //             _signPermit(_spender, _value, _usdc.nonces(_user),
    // _deadline);
    //         _usdc.permit(_user, _spender, _value, _deadline, v, r, s);
    //     }

    //     function _signPermit(
    //         address _spender,
    //         uint256 _value,
    //         uint256 _nonce,
    //         uint256 deadline
    //     )
    //         internal
    //         view
    //         returns (uint8 v, bytes32 r, bytes32 s)
    //     {
    //         SigUtils.Permit memory permit = SigUtils.Permit({
    //             owner: _user,
    //             spender: _spender,
    //             value: _value,
    //             nonce: _nonce,
    //             deadline: deadline
    //         });
    //         bytes32 digest = _sigUtils.getTypedDataHash(permit);
    //         return vm.sign(_userPrivKey, digest);
    //     }
}
