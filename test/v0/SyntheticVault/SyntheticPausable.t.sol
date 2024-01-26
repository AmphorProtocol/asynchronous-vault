// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/SynthVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../../utils/SigUtils.sol";
import "./SyntheticBase.t.sol";

contract SyntheticPausableTests is SyntheticBaseTests {
    SigUtils internal _sigUtils;
    ERC20Permit internal _usdc = ERC20Permit(address(_underlying));
    uint256 internal _userPrivKey;
    uint256 internal _deadline = block.timestamp + 1000;
    address internal _user;

    function _signPermit(
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 deadline
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: _user,
            spender: _spender,
            value: _value,
            nonce: _nonce,
            deadline: deadline
        });
        bytes32 digest = _sigUtils.getTypedDataHash(permit);
        return vm.sign(_userPrivKey, digest);
    }

    function _additionnalSetup() internal override {
        _sigUtils = new SigUtils(_usdc.DOMAIN_SEPARATOR());
        _userPrivKey = 0xA11CE;
        _user = vm.addr(_userPrivKey);
        giveEthUnderlyingAndApprove(_user);
    }

    function test_OwnerCanPause() public {
        _synthVault.pause();
        assertEq(_synthVault.paused(), true);
    }

    function test_notOwnerCantPause() public {
        vm.prank(address(0x1234));

        vm.expectRevert();
        _synthVault.pause();
    }

    function test_OwnerCanUnpause() public {
        _synthVault.pause();
        _synthVault.unpause();
        assertEq(_synthVault.paused(), false);
    }

    function test_notOwnerCantUnpause() public {
        _synthVault.pause();
        vm.prank(address(0x1234));

        vm.expectRevert();
        _synthVault.unpause();
    }

    function test_cantDoubleUnpause() public {
        _synthVault.pause();
        _synthVault.unpause();
        vm.expectRevert();
        _synthVault.unpause();
    }

    function test_cantDoublepause() public {
        _synthVault.pause();
        vm.expectRevert();
        _synthVault.pause();
    }

    function test_userCantDeposit() public {
        _synthVault.pause();
        giveEthUnderlyingAndApprove(_user);

        vm.startPrank(_user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxDeposit.selector, _user, 1, 0
            )
        );
        _synthVault.deposit(1, _user);
    }

    function test_userCantMintWhenPaused() public {
        _synthVault.pause();
        giveEthUnderlyingAndApprove(_user);

        vm.startPrank(_user);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     SynthVault.ERC4626ExceededMaxMint.selector,
            //     _user,
            //     1,
            //     0
            // )
        );
        _synthVault.mint(1, _user);
    }

    function test_userCantDepositWithPermit() public {
        _synthVault.pause();
        giveEthUnderlyingAndApprove(_user);

        vm.startPrank(_user);

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(address(_synthVault), 1, _usdc.nonces(_user), _deadline);
        vm.startPrank(_user);

        vm.expectRevert(
            abi.encodeWithSelector(
                SynthVault.ERC4626ExceededMaxDeposit.selector, _user, 1, 0
            )
        );
        PermitParams memory params =
            PermitParams({ value: 1, deadline: _deadline, v: v, r: r, s: s });
        _synthVault.depositWithPermit(1, _user, params);
    }

    function test_userCantMintWithPermitWhenPaused() public {
        _synthVault.pause();
        giveEthUnderlyingAndApprove(_user);

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(address(_synthVault), 1, _usdc.nonces(_user), _deadline);
        vm.startPrank(_user);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     SynthVault.ERC4626ExceededMaxMint.selector,
            //     _user,
            //     1,
            //     0
            // )
        );
        PermitParams memory params =
            PermitParams({ value: 1, deadline: _deadline, v: v, r: r, s: s });

        _synthVault.mintWithPermit(1, _user, params);
    }

    function test_userCanWithdraw() public {
        uint256 amount = 1000 * 10 ** 6;
        giveEthUnderlyingAndApprove(_user);
        vm.prank(_user);
        _synthVault.deposit(amount, _user);
        _synthVault.pause();
        vm.startPrank(_user);
        vm.expectRevert();
        _synthVault.withdraw(amount, _user, _user);
    }

    function test_userCantRedeem() public {
        uint256 amount = 1000 * 10 ** 6;
        giveEthUnderlyingAndApprove(_user);
        vm.prank(_user);
        _synthVault.deposit(amount, _user);
        _synthVault.pause();
        vm.startPrank(_user);
        uint256 shares = _getSharesBalance(_user);
        vm.expectRevert(
            // ERC20Pausable.EnforcedPause.selector
        );
        _synthVault.redeem(shares, _user, _user);
    }

    function test_unPausingShouldGetBackToNormal() public {
        _synthVault.pause();
        _synthVault.unpause();
        giveEthUnderlyingAndApprove(_user);
        vm.startPrank(_user);
        _synthVault.deposit(1, _user);
        _synthVault.mint(1, _user);
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(address(_synthVault), 1, _usdc.nonces(_user), _deadline);
        vm.startPrank(_user);
        PermitParams memory params =
            PermitParams({ value: 1, deadline: _deadline, v: v, r: r, s: s });
        _synthVault.mintWithPermit(1, _user, params);
        (v, r, s) =
            _signPermit(address(_synthVault), 1, _usdc.nonces(_user), _deadline);
        vm.startPrank(_user);
        params =
            PermitParams({ value: 1, deadline: _deadline, v: v, r: r, s: s });
        _synthVault.depositWithPermit(1, _user, params);
        _synthVault.withdraw(1, _user, _user);
        _synthVault.redeem(1, _user, _user);
    }
}
