// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./SyntheticBase.t.sol";

contract SyntheticDepositAndWithdrawTests is SyntheticBaseTests {
    using Math for uint256;

    function test_SimpleDepositAndWithdraw() public {
        uint256 depositAmount = 10 ** _underlyingDecimals; // 1 ETH / 100 000 000 000.00000 USDC
        uint256 vaultUnderlyingBalance =
            IERC20(_underlying).balanceOf(address(_synthVault));

        deal(address(_underlying), _signer, depositAmount, false);
        vm.startPrank(_signer);
        IERC20(_underlying).approve(address(_synthVault), depositAmount);
        uint256 sharesExpected = _synthVault.convertToShares(depositAmount);
        _synthVault.deposit(depositAmount, _signer);
        assertEq(
            _getSharesBalance(_signer),
            depositAmount * 10 ** _decimalOffset,
            "Signer doesn't have the correct amount of ASV tokens after a deposit"
        );
        assertEq(
            sharesExpected,
            _getSharesBalance(_signer),
            "Shares expected should be equal to the shares balance"
        );
        assertEq(
            _getUnderlyingBalance(address(_synthVault)),
            vaultUnderlyingBalance + depositAmount,
            "synthVault should have 0 undelying token units after a deposit"
        );
        assertEq(
            IERC20(_underlying).balanceOf(_signer),
            0,
            "Signer should have no undelying after a deposit"
        );
        _synthVault.withdraw(depositAmount, _signer, _signer);
        vm.stopPrank();

        assertEq(
            IERC20(_underlying).balanceOf(address(_synthVault)),
            vaultUnderlyingBalance,
            "synthVault should have 0 undelying token units after a withdraw"
        );

        assertEq(
            IERC20(_underlying).balanceOf(_signer),
            depositAmount,
            "Signer should have his undelying back after a withdraw"
        );
        assertEq(
            IERC20(_synthVault).balanceOf(_signer),
            0,
            "Signer doesn't have the correct amount of ASV tokens after a withdraw"
        );
    }

    function test_depositZero() public {
        giveEthUnderlyingAndApprove(_signer);
        uint256 underlyingBefore = _getUnderlyingBalance(_signer);
        uint256 shareBefore = _getSharesBalance(_signer);
        uint256 vaultUnderlyingBalance =
            _getUnderlyingBalance(address(_synthVault));
        vm.prank(_signer);
        uint256 sharesExpected = _synthVault.previewDeposit(0);

        _synthVault.deposit(0, _signer);
        assertEq(
            _getUnderlyingBalance(_signer),
            underlyingBefore,
            "Signer should have the same amount of underlying after a deposit of 0"
        );
        assertEq(
            _getSharesBalance(_signer),
            shareBefore,
            "Signer should have the same amount of shares after a deposit of 0"
        );
        assertEq(
            shareBefore - _getSharesBalance(_signer),
            sharesExpected,
            "Signer should have the same amount of shares after a deposit of 0"
        );
        assertEq(
            _getUnderlyingBalance(address(_synthVault)),
            vaultUnderlyingBalance,
            "synthVault should have the same amount of underlying after a deposit of 0"
        );
    }

    function test_depositMinSharesTooLow() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toDeposit = 10 * 10 ** ERC20(_underlying).decimals();
        uint256 sharesPreview = _synthVault.previewDeposit(toDeposit);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626NotEnoughSharesMinted.selector,
                _signer,
                sharesPreview,
                sharesPreview + 1
            )
        );
        _synthVault.depositMinShares(toDeposit, _signer, sharesPreview + 1);
    }

    function test_depositMinSharesExact() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toDeposit = 10 * 10 ** ERC20(_underlying).decimals();
        uint256 sharesPreview = _synthVault.previewDeposit(toDeposit);
        uint256 sharesMinted =
            _synthVault.depositMinShares(toDeposit, _signer, sharesPreview);
        assertEq(
            sharesMinted,
            sharesPreview,
            "Shares minted should be equal to the preview"
        );
    }

    function test_depositMinShares1PercentSlippage() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toDeposit = 1000 * 10 ** ERC20(_underlying).decimals();
        uint256 sharesPreview = _synthVault.previewDeposit(toDeposit);

        uint256 sharesMinted = _synthVault.depositMinShares(
            toDeposit.mulDiv(9900, 10000),
            _signer,
            sharesPreview.mulDiv(9900, 10000)
        );
        assertGe(sharesMinted, sharesPreview.mulDiv(9900, 10000));
    }

    function test_depositMinSharesNotEnough() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toDeposit = 10 * 10 ** ERC20(_underlying).decimals();
        uint256 sharesPreview = _synthVault.previewDeposit(toDeposit);
        uint256 actualShares =
            _synthVault.previewDeposit(toDeposit.mulDiv(9899, 10000));
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626NotEnoughSharesMinted.selector,
                _signer,
                actualShares,
                sharesPreview.mulDiv(9900, 10000)
            )
        );
        _synthVault.depositMinShares(
            toDeposit.mulDiv(9899, 10000),
            _signer,
            sharesPreview.mulDiv(9900, 10000)
        );
    }

    function test_withdrawZero() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        _synthVault.deposit(100 * 10 ** 6, _signer);

        uint256 underlyingBefore = _getUnderlyingBalance(_signer);
        uint256 shareBefore = _getSharesBalance(_signer);
        uint256 vaultUnderlyingBalance =
            _getUnderlyingBalance(address(_synthVault));
        _synthVault.withdraw(0, _signer, _signer);
        vm.stopPrank();

        assertEq(
            _getUnderlyingBalance(_signer),
            underlyingBefore,
            "Signer should have the same amount of underlying after a withdraw of 0"
        );
        assertEq(
            _getSharesBalance(_signer),
            shareBefore,
            "Signer should have the same amount of shares after a withdraw of 0"
        );
        assertEq(
            _getUnderlyingBalance(address(_synthVault)),
            vaultUnderlyingBalance,
            "synthVault should have the same amount of underlying after a withdraw of 0"
        );
    }

    function test_advancedDepositAndWithdraw() public {
        // 10 ** 18 // 1 ETH / 10 000 000 000 000.00000 USDC
        _testAdvancedDepositAndWithdraw(
            10 ** 18, type(uint256).max, 34545678908765, 9876546789
        ); // 34545678908765 is a random number
            // _testAdvancedDepositAndWithdraw(3456789, 34545678908765); // 34545678908765 > 3456789 are both random numbers
            // _testAdvancedDepositAndWithdraw(34545678908765, 3456789); // 34545678908765 > 3456789 are both random numbers
    }

    function _testAdvancedDepositAndWithdraw(
        uint256 balanceAmount,
        uint256 approvalAmount,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) internal {
        uint256 vaultUnderlyingBalance =
            IERC20(_underlying).balanceOf(address(_synthVault));

        // Fund the vault with some underlying, and mint the corresponding shares tokens
        deal(address(_underlying), _signer, balanceAmount, false);
        vm.startPrank(_signer);
        IERC20(_underlying).approve(address(_synthVault), approvalAmount); // Max approval, just to test an eventual edge case
        _synthVault.deposit(depositAmount, _signer);
        assertEq(
            IERC20(_synthVault).balanceOf(_signer),
            depositAmount * 10 ** _decimalOffset,
            "Signer doesn't have the correct amount of ASV tokens after a deposit"
        );
        assertEq(
            IERC20(_underlying).balanceOf(address(_synthVault)),
            vaultUnderlyingBalance + depositAmount,
            "synthVault should have 0 underlying token units after a deposit"
        );
        assertEq(
            IERC20(_underlying).balanceOf(_signer),
            balanceAmount - depositAmount,
            "Signer should have the randomUnderlyingBalanceOffset undelying after a deposit"
        );
        _synthVault.withdraw(withdrawAmount, _signer, _signer);
        vm.stopPrank();

        // Verify balances
        assertEq(
            IERC20(_underlying).balanceOf(address(_synthVault)),
            vaultUnderlyingBalance + depositAmount - withdrawAmount,
            "synthVault should have 0 undelying token units after a withdraw"
        );
        assertEq(
            IERC20(_underlying).balanceOf(_signer),
            balanceAmount - depositAmount + withdrawAmount,
            "Signer should have his undelying back after a withdraw"
        );
        assertEq(
            IERC20(_synthVault).balanceOf(_signer),
            (depositAmount - withdrawAmount) * 10 ** _decimalOffset,
            "Signer doesn't have the correct amount of ASV tokens after a withdraw"
        );
    }

    function test_withdrawForOtherUser() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        _synthVault.deposit(100 * 10 ** 6, _signer);
        uint256 sharesBefore = _getSharesBalance(_signer);
        ERC20(_synthVault).approve(_signer2, _getSharesBalance(_signer));
        vm.stopPrank();

        vm.prank(_signer2);
        uint256 shares = _synthVault.withdraw(100 * 10 ** 6, _signer2, _signer);
        assertEq(
            _getUnderlyingBalance(_signer2),
            100 * 10 ** 6,
            "Signer2 should have the underlying after a withdraw for signer"
        );
        assertEq(
            sharesBefore,
            shares,
            "Shares return should be equal to the shares hold by signer"
        );
    }

    function test_redeemForOtherUser() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        _synthVault.deposit(100 * 10 ** 6, _signer);
        ERC20(_synthVault).approve(_signer2, _getSharesBalance(_signer));
        vm.stopPrank();

        vm.startPrank(_signer2);
        uint256 assets =
            _synthVault.redeem(_getSharesBalance(_signer), _signer2, _signer);
        assertEq(
            assets,
            100 * 10 ** 6,
            "Redeem return should be equal to the amount of underlying originally deposited"
        );
        assertEq(
            _getUnderlyingBalance(_signer2),
            100 * 10 ** 6,
            "Signer2 should have the underlying after a withdraw for signer"
        );
    }

    function test_redeemForOtherUserUintMax() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        _synthVault.deposit(100 * 10 ** 6, _signer);
        ERC20(_synthVault).approve(_signer2, UINT256_MAX);
        vm.stopPrank();

        vm.startPrank(_signer2);
        uint256 previewAssets =
            _synthVault.previewRedeem(_getSharesBalance(_signer));
        uint256 _assets =
            _synthVault.redeem(_getSharesBalance(_signer), _signer2, _signer);

        assertEq(
            _getUnderlyingBalance(_signer2),
            100 * 10 ** 6,
            "Signer2 should have the underlying after a withdraw for signer"
        );
        assertEq(
            _assets,
            100 * 10 ** 6,
            "Assets return should be equal to the underlying balance of signer2"
        );
        assertEq(
            previewAssets,
            100 * 10 ** 6,
            "Preview assets should be equal to the underlying balance of signer2"
        );
        assertEq(
            ERC20(_synthVault).allowance(_signer, _signer2),
            UINT256_MAX,
            "Signer2 allowance should remain unchanged after redeeming for signer"
        );
        vm.stopPrank();
    }

    function test_withdrawForOtherUserUintMax() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        _synthVault.deposit(100 * 10 ** 6, _signer);
        ERC20(_synthVault).approve(_signer2, UINT256_MAX);
        vm.stopPrank();
        uint256 sharesBefore = _getSharesBalance(_signer);
        uint256 sharesPreview = _synthVault.previewWithdraw(100 * 10 ** 6);
        vm.startPrank(_signer2);
        uint256 shares = _synthVault.withdraw(100 * 10 ** 6, _signer2, _signer);
        assertEq(
            _getUnderlyingBalance(_signer2),
            100 * 10 ** 6,
            "Signer2 should have the underlying after a withdraw for signer"
        );
        assertEq(
            sharesBefore,
            shares,
            "Shares return should be equal to the shares hold by signer"
        );
        assertEq(
            sharesPreview,
            shares,
            "Shares return should be equal to the preview of the amount of shares"
        );
        assertEq(
            ERC20(_synthVault).allowance(_signer, _signer2),
            UINT256_MAX,
            "Signer2 allowance should remain unchanged after redeeming for signer"
        );
        vm.stopPrank();
    }

    function test_redeem() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 underlyingBefore = _getUnderlyingBalance(_signer);
        _synthVault.deposit(underlyingBefore, _signer);

        uint256 assets =
            _synthVault.redeem(_getSharesBalance(_signer), _signer, _signer);
        assertEq(
            assets,
            underlyingBefore,
            "Redeem return should be equal to the amount of underlying originally deposited"
        );
        assertEq(
            _getUnderlyingBalance(_signer),
            underlyingBefore,
            "Signer should have the underlying after a withdraw for signer"
        );
    }

    // function test_mint() public {
    //     giveEthUnderlyingAndApprove(_signer);
    //     vm.startPrank(_signer);
    //     uint256 underlyingBefore = _getUnderlyingBalance(_signer);
    //     uint256 toMint = 10 * 10 ** ERC20(_underlying).decimals();
    //     uint256 underlyingPreview = _synthVault.previewMint(toMint);
    //     uint256 mintReturn = _synthVault.mint(toMint, _signer);
    //     uint256 underlyingAfter = _getUnderlyingBalance(_signer);

    //     assertEq(
    //         mintReturn,
    //         underlyingPreview,
    //         "Mint return should be equal to the amount of underlying originally deposited"
    //     );
    //     assertEq(
    //         underlyingAfter,
    //         underlyingBefore - mintReturn,
    //         "Mint return should be equal to the amount of underlying actually deposited"
    //     );
    // }

    function test_mintMaxAssets() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toMint = 10 * 10 ** ERC20(_underlying).decimals();
        uint256 underlyingPreview = _synthVault.previewMint(toMint);
        console.log("underlyingPreview", underlyingPreview);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626TooMuchAssetsDeposited.selector,
                _signer,
                underlyingPreview,
                underlyingPreview - 1
            )
        );
        _synthVault.mintMaxAssets(toMint, _signer, underlyingPreview - 1);
    }

    function test_mintMaxAssetsTooHigh() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toMint = 10 * 10 ** ERC20(_synthVault).decimals();
        uint256 underlyingPreview = _synthVault.previewMint(toMint);
        uint256 underlyingPreviewExcess = _synthVault.previewMint(toMint + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626TooMuchAssetsDeposited.selector,
                _signer,
                underlyingPreviewExcess,
                underlyingPreview
            )
        );
        _synthVault.mintMaxAssets(toMint + 1, _signer, underlyingPreview);
    }

    function test_mintMaxAssetsSame() public {
        giveEthUnderlyingAndApprove(_signer);
        vm.startPrank(_signer);
        uint256 toMint = 10 * 10 ** ERC20(_synthVault).decimals();
        uint256 underlyingPreview = _synthVault.previewMint(toMint);

        uint256 assetDeposited =
            _synthVault.mintMaxAssets(toMint, _signer, underlyingPreview);
        assertEq(
            assetDeposited,
            underlyingPreview,
            "Asset deposited should be equal to the preview"
        );
    }
}
