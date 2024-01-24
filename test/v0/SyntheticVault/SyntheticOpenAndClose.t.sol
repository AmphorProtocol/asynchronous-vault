// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./SyntheticBase.t.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SyntheticOpenAndClose is SyntheticBaseTests {
    using Math for uint256;

    function _additionnalSetup() internal override {
        giveEthUnderlyingAndApprove(_signer);
        giveEthUnderlyingAndApprove(_signer2);
        giveEthUnderlyingAndApprove(_amphorLabs);
        giveEthUnderlyingAndApprove(address(this));
        _synthVault.setFees(20 * 100);   
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, _signer);
    }

    
    function test_isOpen() public {
        assertEq(_synthVault.isOpen(), true);
    }

    function test_VaultIsClosedAfterClose() public {
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, _signer);

        _synthVault.close();
        assertEq(_synthVault.isOpen(), false);
    }

    function test_VaultIsOpenAfterOpen() public {
        // deal(address(_underlying), _signer, 5_000 * 10 ** _underlyingDecimals, false);

        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, _signer);
        _synthVault.close();
        _synthVault.open(5_000 * 10 ** _underlyingDecimals);
        assertEq(_synthVault.isOpen(), true);
    }

    function test_DoubleClose() public {
        vm.prank(_signer);
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, _signer);
        _synthVault.close();
        vm.expectRevert(SynthVault.VaultIsLocked.selector);
        _synthVault.close();
    }

    function test_DoubleOpen() public {
        _synthVault.close();
        _synthVault.open(0);
        vm.expectRevert(SynthVault.VaultIsOpen.selector);
        _synthVault.open(0);
    }

    function test_surplusOpen() public {
        _synthVault.setFees(20 * 100);
        _synthVault.close();
        uint256 ownerUnderlyingBalance = 10_000 * 10 ** _underlyingDecimals;
        uint256 amountToGiveBackToTheVault = ownerUnderlyingBalance / 2;
        uint256 ownerUnderlyingBalanceAferOpenWithoutFees =
            ownerUnderlyingBalance - amountToGiveBackToTheVault;

        deal(address(_underlying), address(this), ownerUnderlyingBalance);

        IERC20(_underlying).approve(
            address(_synthVault), ownerUnderlyingBalance
        );
        uint16 perfFees = _synthVault.feesInBps();
        _synthVault.open(amountToGiveBackToTheVault);

        uint256 profits = amountToGiveBackToTheVault - _synthVault.totalAssets();
        uint256 afterOpenOwnerUnderlyingBalance =
            _getUnderlyingBalance(address(this));

        assertEq(
            afterOpenOwnerUnderlyingBalance,
            ownerUnderlyingBalanceAferOpenWithoutFees
                + profits.mulDiv(perfFees, 10000, Math.Rounding.Ceil)
        );
    }

    function test_minusOpen() public {
        vm.prank(_signer);
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, _signer);
        _synthVault.close();
        uint256 lastSavedBalance = _synthVault.totalAssets();
        uint256 ownerUnderlyingBalanceBeforeOpen =
            _getUnderlyingBalance(address(this));

        uint256 amountToGiveBackToTheVault = lastSavedBalance / 2;
        _synthVault.open(amountToGiveBackToTheVault);
        uint256 ownerUnderlyingBalacanceAfterOpen =
            _getUnderlyingBalance(address(this));

        assertEq(
            ownerUnderlyingBalanceBeforeOpen - amountToGiveBackToTheVault,
            ownerUnderlyingBalacanceAfterOpen
        );
    }

    function test_OpenWithZero() public {
        vm.prank(_signer);
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, _signer);
        _synthVault.close();
        uint256 ownerUnderlyingBalanceBeforeOpen =
            _getUnderlyingBalance(address(this));

        _synthVault.open(0);
        uint256 ownerUnderlyingBalacanceAfterOpen =
            _getUnderlyingBalance(address(this));

        assertEq(
            ownerUnderlyingBalanceBeforeOpen, ownerUnderlyingBalacanceAfterOpen
        );
    }

    function test_closeLastBalance() public {
        address user = _signer;
        address user2 = _signer2;
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        vm.prank(user);
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, user);
        vm.prank(user2);
        _synthVault.deposit(3_000 * 10 ** _underlyingDecimals, user2);

        _synthVault.close();

        assertEq(
            _synthVault.totalAssets(),
            5_000 * 10 ** _underlyingDecimals
                + 3_000 * 10 ** _underlyingDecimals
        );
    }

    function test_closeOwnerUnderlyingBalance() public {
        address user = _signer;
        address user2 = _signer2;
        uint256 ownerUnderlyingBeforeClose =
            _getUnderlyingBalance(address(this));
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        vm.prank(user);
        _synthVault.deposit(5_000 * 10 ** _underlyingDecimals, user);
        vm.prank(user2);
        _synthVault.deposit(3_000 * 10 ** _underlyingDecimals, user2);

        _synthVault.close();

        assertEq(
            _getUnderlyingBalance(address(this)) - ownerUnderlyingBeforeClose,
            5_000 * 10 ** _underlyingDecimals
                + 3_000 * 10 ** _underlyingDecimals
        );
    }

    function test_UserProfits() public {
        address user = _signer;
        address user2 = _signer2;
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        uint256 userDeposit = 5_000 * 10 ** _underlyingDecimals;
        uint256 user2Deposit = 3_000 * 10 ** _underlyingDecimals;
        vm.prank(user);
        _synthVault.deposit(userDeposit, user);
        vm.prank(user2);
        _synthVault.deposit(user2Deposit, user2);

        _synthVault.close();
        uint256 profitsInBips = 2000;
        _synthVault.open(
            (_synthVault.totalAssets() * (10000 + profitsInBips)) / 10000
        );

        _checkUserProfits(userDeposit, profitsInBips, 0, user);
        _checkUserProfits(user2Deposit, profitsInBips, 0, user2);
    }

    function test_UsersProfitsWithDonation() public {
        address user = _signer;
        address user2 = _signer2;
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        uint256 userDeposit = 5_000 * 10 ** _underlyingDecimals;
        uint256 user2Deposit = 3_000 * 10 ** _underlyingDecimals;
        vm.prank(user);
        _synthVault.deposit(userDeposit, user);
        vm.prank(user2);
        _synthVault.deposit(user2Deposit, user2);

        _synthVault.close();
        uint256 profitsInBips = 2000;

        deal(
            address(_underlying),
            address(_synthVault),
            ERC20(_underlying).balanceOf(address(_synthVault))
                + 1000 * 10 ** _underlyingDecimals
        );
        _synthVault.open(
            (_synthVault.totalAssets() * (10000 + profitsInBips)) / 10000
        );

        _checkUserProfits(userDeposit, profitsInBips, 625000000, user);
        _checkUserProfits(user2Deposit, profitsInBips, 375000000, user2);
    }

    function test_UsersProfitsThankToDonation() public {
        address user = _signer;
        address user2 = _signer2;
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        uint256 userDeposit = 5_000 * 10 ** _underlyingDecimals;
        uint256 user2Deposit = 3_000 * 10 ** _underlyingDecimals;
        vm.prank(user);
        _synthVault.deposit(userDeposit, user);
        vm.prank(user2);
        _synthVault.deposit(user2Deposit, user2);

        _synthVault.close();
        uint256 lossesInBips = 2000;

        deal(
            address(_underlying),
            address(_synthVault),
            ERC20(_underlying).balanceOf(address(_synthVault))
                + 1000 * 10 ** _underlyingDecimals
        );
        _synthVault.open(
            (_synthVault.totalAssets() * (10000 - lossesInBips)) / 10000
        );

        _checkUserProfitsThankToDonation(
            userDeposit, lossesInBips, 625000000, user
        );
        _checkUserProfitsThankToDonation(
            user2Deposit, lossesInBips, 375000000, user2
        );
    }

    function test_UserLossesWithDonation() public {
        address user = _signer;
        address user2 = _signer2;
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        uint256 userDeposit = 5_000 * 10 ** _underlyingDecimals;
        uint256 user2Deposit = 3_000 * 10 ** _underlyingDecimals;
        vm.prank(user);
        _synthVault.deposit(userDeposit, user);
        console.log("user balance", _getSharesBalance(user));
        vm.prank(user2);
        _synthVault.deposit(user2Deposit, user2);

        _synthVault.close();
        uint256 lossesInBips = 2000;

        deal(
            address(_underlying),
            address(_synthVault),
            ERC20(_underlying).balanceOf(address(_synthVault))
                + 1000 * 10 ** _underlyingDecimals
        );
        _synthVault.open(
            (_synthVault.totalAssets() * (10000 - lossesInBips)) / 10_000
        );

        _checkUserLosses(userDeposit, lossesInBips, 625000000, user);
        _checkUserLosses(user2Deposit, lossesInBips, 375000000, user2);
    }

    function test_UserProfitsWithFunkyFees() public {
        _synthVault.setFees(1243);
        test_UserProfits();
    }

    function test_UserProfitsWithFees0() public {
        _synthVault.setFees(0);
        test_UserProfits();
    }

    function _checkUserProfits(
        uint256 userDeposit,
        uint256 underlyingIncreaseInBips,
        uint256 profitFromDonation,
        address user
    ) internal {
        uint256 underlyingIncreaseAmountWithoutFees = userDeposit.mulDiv(
            10000 + underlyingIncreaseInBips, 10000, Math.Rounding.Ceil
        );
        uint256 feesTaken = (underlyingIncreaseAmountWithoutFees - userDeposit)
            .mulDiv(_synthVault.feesInBps(), 10000, Math.Rounding.Ceil);
        uint256 amountToReceive = underlyingIncreaseAmountWithoutFees
            - feesTaken - 1 + profitFromDonation;
        uint256 userPotentialWithdraw =
            _synthVault.previewRedeem(_getSharesBalance(user));
        assertEq(
            amountToReceive,
            userPotentialWithdraw,
            "User won't withdraw the appropriate amount after open"
        );
    }

    function _checkUserProfitsThankToDonation(
        uint256 userDeposit,
        uint256 underlyingDecreaseInBips,
        uint256 profitFromDonation,
        address user
    ) internal {
        uint256 underlyingIncreaseAmountWithoutFees = userDeposit.mulDiv(
            10000 - underlyingDecreaseInBips, 10000, Math.Rounding.Ceil
        );
        uint256 amountToReceive =
            underlyingIncreaseAmountWithoutFees + profitFromDonation;
        uint256 userPotentialWithdraw =
            _synthVault.previewRedeem(_getSharesBalance(user));
        assertEq(
            amountToReceive,
            userPotentialWithdraw,
            "User won't withdraw the appropriate amount after open"
        );
    }

    function test_UserLosses() public {
        address user = _signer;
        address user2 = _signer2;
        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        uint256 userDeposit = 5_000 * 10 ** _underlyingDecimals;
        uint256 user2Deposit = 3_000 * 10 ** _underlyingDecimals;
        vm.prank(user);
        _synthVault.deposit(userDeposit, user);
        vm.prank(user2);
        _synthVault.deposit(user2Deposit, user2);

        _synthVault.close();
        uint256 lossesInBips = 2000;
        _synthVault.open(
            (_synthVault.totalAssets() * (10000 - lossesInBips)) / 10000
        );

        // _checkUserLosses(userDeposit, lossesInBips, 0, user);
        // _checkUserLosses(user2Deposit, lossesInBips, 0, user2);
    }

    function test_UserLossesWithoutFees() public {
        _synthVault.setFees(0);
        test_UserLosses();
    }

    function _checkUserLosses(
        uint256 userDeposit,
        uint256 underlyingDecreaseInBips,
        uint256 profitFromDonation,
        address user
    ) internal {
        uint256 underlyingDecreaseAmountWithoutFees = userDeposit.mulDiv(
            10000 - underlyingDecreaseInBips, 10000, Math.Rounding.Ceil
        );
        uint256 feesTaken = 0;
        uint256 amountToReceive =
            underlyingDecreaseAmountWithoutFees - feesTaken + profitFromDonation;
        uint256 userPotentialWithdraw =
            _synthVault.previewRedeem(_getSharesBalance(user));
        console.log(_getSharesBalance(user));
        assertEq(
            amountToReceive,
            userPotentialWithdraw,
            "User won't withdraw the appropriate amount after open"
        );
    }

    function test_MaxDepositAfterClose() public {
        _synthVault.close();
        assertEq(
            _synthVault.maxDeposit(address(0)),
            0,
            "Max deposit should be 0 after close"
        );
    }

    function test_MaxMintAfterClose() public {
        _synthVault.close();
        assertEq(
            _synthVault.maxMint(address(0)),
            0,
            "Max mint should be 0 after close"
        );
    }

    function test_MaxRedeemAfterClose() public {
        _synthVault.close();
        assertEq(
            _synthVault.maxRedeem(address(0)),
            0,
            "Max redeem should be 0 after close"
        );
    }

    function test_MaxWithdrawAfterClose() public {
        _synthVault.close();
        assertEq(
            _synthVault.maxWithdraw(address(0)),
            0,
            "Max redeem should be 0 after close"
        );
    }

    function test_userRedeemAfterClose() public {
        address user = _signer;
        giveEthUnderlyingAndApprove(user);
        vm.prank(user);
        _synthVault.deposit(100 * 10 ** 6, user);
        _synthVault.close();

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxRedeem.selector,
                user,
                1,
                0
            )
        );
        _synthVault.redeem(1, user, user);
    }

    function test_userWithdrawAfterClose() public {
        address user = _signer;

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxWithdraw.selector,
                user,
                1,
                0
            )
        );
        _synthVault.withdraw(1, user, user);
    }

    function test_withdrawAfterOpen() public {
        address user = _signer;
        uint256 userBalance = giveEthUnderlyingAndApprove(user);

        vm.prank(user);
        _synthVault.deposit(userBalance, user);
        _synthVault.close();
        _synthVault.open(userBalance);
        vm.startPrank(user);
        _synthVault.withdraw(userBalance, user, user);
        assertEq(
            _getUnderlyingBalance(user),
            userBalance,
            "User should have its underlying back"
        );
    }

    function test_redeemAfterClose() public {
        address user = _signer;
        giveEthUnderlyingAndApprove(user);
        vm.prank(user);
        _synthVault.deposit(100 * 10 ** 6, user);
        _synthVault.close();

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxWithdraw.selector,
                user,
                1,
                0
            )
        );
        _synthVault.withdraw(1, user, user);
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxRedeem.selector,
                user,
                1,
                0
            )
        );
        _synthVault.redeem(1, user, user);
    }

    function test_depositAfterClose() public {
        address user = _signer;
        giveEthUnderlyingAndApprove(user);
        _synthVault.close();
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxDeposit.selector,
                user,
                100 * 10 ** 6,
                0
            )
        );
        _synthVault.deposit(100 * 10 ** 6, user);
    }

    function test_mintAfterClose() public {
        address user = _signer;
        giveEthUnderlyingAndApprove(user);
        _synthVault.close();
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxMint.selector,
                user,
                100 * 10 ** 6,
                0
            )
        );
        _synthVault.mint(100 * 10 ** 6, user);
    }

    function test_closeMultipleEpochs() public {
        address user = _signer;
        address user2 = _signer2;
        address user3 = address(0x123);

        giveEthUnderlyingAndApprove(user);
        giveEthUnderlyingAndApprove(user2);
        giveEthUnderlyingAndApprove(user3);

        vm.prank(user);
        _synthVault.deposit(11 * 10 ** 6, user);
        vm.prank(user2);
        _synthVault.deposit(22 * 10 ** 6, user2);
        vm.prank(user3);
        _synthVault.deposit(33 * 10 ** 6, user3);

        assertEq(
            _synthVault.totalAssets(),
            0,
            "Vault lastSavedBalance should be 0"
        );

        _synthVault.close();

        assertEq(
            _getUnderlyingBalance(address(_synthVault)),
            0,
            "Vault should be empty"
        );
        assertEq(
            _synthVault.totalAssets(),
            66 * 10 ** 6,
            "Vault should have 66 * 10 ** 6 underlying"
        );

        giveEthUnderlyingAndApprove(address(this));

        _synthVault.open(70 * 10 ** 6);

        assertEq(
            _getUnderlyingBalance(address(_synthVault)),
            692 * 10 ** 5,
            "Vault should have 70 * 10 ** 6 underlying"
        );

        assertEq(
            _synthVault.totalAssets(),
            0,
            "Vault lastSavedBalance should be 0"
        );

        uint256 vaultBalance = 692 * 10 ** 5;

        vm.prank(user);
        _synthVault.deposit(11 * 10 ** 6, user);
        vm.prank(user2);
        _synthVault.deposit(22 * 10 ** 6, user2);
        vm.prank(user3);
        _synthVault.deposit(33 * 10 ** 6, user3);

        _synthVault.close();

        vaultBalance += 66 * 10 ** 6;

        assertEq(
            _getUnderlyingBalance(address(_synthVault)),
            0,
            "Vault should be empty"
        );
        assertEq(
            _synthVault.totalAssets(),
            vaultBalance,
            "Vault should have 1352 * 10 ** 5 underlying (see {vaultBalance})"
        );
    }
}
