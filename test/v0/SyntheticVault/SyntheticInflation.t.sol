// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./SyntheticBase.t.sol";

contract SyntheticInflationTests is SyntheticBaseTests {
    uint256 internal _underlyingBaseDepositPower = 10;
    uint256 internal _underlyingBaseDeposit = 10 ** _underlyingBaseDepositPower;
    uint256 internal _baseDepositDecimalsCount = _underlyingBaseDepositPower + 1;
    uint256 internal _zeroBaseDeposit = 0;

    address internal _attacker;
    address internal _victim;

    function _additionnalSetup() internal override {
        // Bootstrap the SynthVault contract

        IERC20(_underlying).approve(
            address(_synthVault), _underlyingBaseDeposit
        );
        _attacker = _signer;
        _victim = _signer2;
    }

    function test_classicAttack() public {
        // here donation is just victimDepositAmount + 1, so the attack should
        // not work

        uint256 victimDepositAmount = 10;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = victimDepositAmount + 1;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower2() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 2 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower3() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;

        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 3 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower4() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 4 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower5() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 5 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower6() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 6 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower7() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 7 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithPower8() public {
        uint256 victimDepositAmount = 10_000 * 10 ** _underlyingDecimals;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = 10 ** 8 * victimDepositAmount;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _zeroBaseDeposit
        );
    }

    function test_attackWithExtremlyHighDonation() public {
        // Testing inflation with an over big donation (so the attack should
        // work)
        uint256 victimDepositAmount = 10;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount = victimDepositAmount
            ** (_decimalOffset + _baseDepositDecimalsCount + 1);
        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _underlyingBaseDeposit
        );
    }

    function test_BaseFuzzInflation(uint8 donationPowerFactor) public {
        vm.assume(
            donationPowerFactor < _decimalOffset + _baseDepositDecimalsCount + 1
        );
        // Test inflation with only the base underlying amount in the vault
        // This will try the attack with an amount up to vaults decimals +
        // bootstrap decimal + 1 (+99%)
        // For usdc, this means that with a 24 offset and a 10k USDC bootstrap
        // we can go up to a 35 decimals amount
        // up to  10 ** 29 . 000 000 USDC

        uint256 victimDepositAmount = 10;
        uint256 attackDepositAmount = 1;
        uint256 attackDonationAmount =
            victimDepositAmount ** donationPowerFactor;

        _testFailingAttack(
            victimDepositAmount,
            attackDepositAmount,
            attackDonationAmount,
            _underlyingBaseDeposit
        );
    }

    function _testSucceeddingAttack(
        uint256 victimDepositAmount,
        uint256 attackDepositAmount,
        uint256 attackDonationAmount,
        uint256 underlyingBaseDeposit
    )
        private
    {
        // Fund the vault with some (vaultStartBalanceAddon) underlying, and
        // mint the corresponding shares tokens
        if (underlyingBaseDeposit > 0) {
            deal(
                address(_underlying),
                address(this),
                underlyingBaseDeposit,
                false
            );
            IERC20(_underlying).approve(
                address(_synthVault), underlyingBaseDeposit
            );
            _synthVault.deposit(underlyingBaseDeposit, address(this));
        }

        giveEthUnderlyingAndApprove(
            _attacker, attackDepositAmount + attackDonationAmount
        );

        // Do the attack
        vm.startPrank(_attacker);
        _synthVault.deposit(attackDepositAmount, _attacker);
        IERC20(_underlying).transfer(address(_synthVault), attackDonationAmount);
        vm.stopPrank();

        // Victim deposits some underlying
        giveEthUnderlyingAndApprove(_victim, victimDepositAmount);
        vm.prank(_victim);
        _synthVault.deposit(victimDepositAmount, _victim);

        assertFalse(
            victimDepositAmount - 1 // -1 because of the Math.Rounding.Floor
                <= _synthVault.previewRedeem(
                    IERC20(address(_synthVault)).balanceOf(_victim)
                ),
            "victim should not have the appropriate underlying tokens amount"
        );
        console.log('Attack "succeed":');
        console.log(
            "Attacker's final balance",
            _synthVault.previewRedeem(_getSharesBalance(_attacker))
                / 10 ** ERC20(_underlying).decimals()
        );
        console.log(
            "Victim's final balance",
            _synthVault.previewRedeem(_getSharesBalance(_victim))
                / 10 ** ERC20(_underlying).decimals()
        );
        console.log(
            "Vault's final balance",
            ERC20(_underlying).balanceOf(address(_synthVault))
        );

        console.log(
            "attacker loss:",
            (
                attackDonationAmount + attackDepositAmount
                    - _synthVault.previewRedeem(_getSharesBalance(_attacker))
            ) / 10 ** ERC20(_underlying).decimals(),
            " USDC"
        );
        console.log(
            "victim loss:",
            (
                victimDepositAmount
                    - _synthVault.convertToAssets(_getSharesBalance(_victim))
            ),
            // 10 ** ERC20(_underlying).decimals(),
            "wei USDC"
        );
    }

    function _testFailingAttack(
        uint256 victimDepositAmount,
        uint256 attackDepositAmount,
        uint256 attackDonationAmount,
        uint256 underlyingBaseDeposit
    )
        private
    {
        if (underlyingBaseDeposit > 0) {
            deal(
                address(_underlying),
                address(this),
                underlyingBaseDeposit,
                false
            );
            IERC20(_underlying).approve(
                address(_synthVault), underlyingBaseDeposit
            );
            _synthVault.deposit(underlyingBaseDeposit, address(this));
        }

        giveEthUnderlyingAndApprove(
            _attacker, attackDepositAmount + attackDonationAmount
        );

        // Do the attack
        vm.startPrank(_attacker);
        _synthVault.deposit(attackDepositAmount, _attacker);
        IERC20(_underlying).transfer(address(_synthVault), attackDonationAmount);
        vm.stopPrank();

        // Victim deposits some underlying
        giveEthUnderlyingAndApprove(_victim, victimDepositAmount);
        vm.prank(_victim);
        _synthVault.deposit(victimDepositAmount, _victim);

        console.log("victimDepositAmount", victimDepositAmount);
        console.log(
            "Victim's final balance",
            _synthVault.previewRedeem(_getSharesBalance(_victim))
        );
        assertEq(
            victimDepositAmount, // -1 because of the Math.Rounding.Floor
            _synthVault.previewRedeem(_getSharesBalance(_victim)),
            "Victim should have an appropriate underlying tokens amount"
        );
        console.log("Attack failed:");
        console.log(
            "attacker loss:",
            (
                attackDonationAmount + attackDepositAmount
                    - _synthVault.previewRedeem(_getSharesBalance(_attacker))
            ) / 10 ** ERC20(_underlying).decimals(),
            " USDC"
        );
        console.log(
            "victim loss:",
            (
                victimDepositAmount
                    - _synthVault.previewRedeem(_getSharesBalance(_victim))
            ),
            // 10 ** ERC20(_underlying).decimals(),
            "wei USDC"
        );
    }
}
