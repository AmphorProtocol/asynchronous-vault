// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../BaseVault/BaseVault.t.sol";
import "@src/SynthVaultPermit.sol";

contract SyntheticBaseTests is BaseVaultTest {
    /*
    _                          _                        ____                    _     _              _     _            _                  _         
    / \     _ __ ___    _ __   | |__     ___    _ __    / ___|   _   _   _ __   |
    |_  | |__     ___  | |_  (_)   ___    | |_    ___   ___  | |_   ___ 
    / _ \   | '_ ` _ \  | '_ \  | '_ \   / _ \  | '__|   \___ \  | | | | | '_ \  |
    __| | '_ \   / _ \ | __| | |  / __|   | __|  / _ \ / __| | __| / __|
    / ___ \  | | | | | | | |_) | | | | | | (_) | | |       ___) | | |_| | | | |
    | | |_  | | | | |  __/ | |_  | | | (__    | |_  |  __/ \__ \ | |_  \__ \
    /_/   \_\ |_| |_| |_| | .__/  |_| |_|  \___/  |_|      |____/   \__, | |_|
    |_|  \__| |_| |_|  \___|  \__| |_|  \___|    \__|  \___| |___/  \__| |___/
    |_|                                       |___/                                                                                
    */

    // Declare global attributes here
    SynthVaultPermit internal _synthVault;
    ERC20 internal USDC = ERC20(vm.envAddress("USDC_MAINNET")); // can also be
        // vm.envAddress("WETH_MAINNET") or vm.envAddress("WBTC_MAINNET")
    ERC20 internal _underlying = ERC20(vm.envAddress("DAI_MAINNET")); // can
        // also be vm.envAddress("WETH_MAINNET") or
        // vm.envAddress("WBTC_MAINNET")
    uint256 internal _underlyingDecimals = ERC20(_underlying).decimals();
    uint8 internal _decimalOffset = 0;
    //_underlying == vm.envAddress("DAI_MAINNET") ? 24 : 35; // 24 for USDC, 35
    // for WETH, 35 for WBTC -> we should put less
    address internal _usdt = vm.envAddress("USDT_MAINNET");
    // Declare AmphorLabs wallet address here
    address internal _amphorLabs = 0xa51337F0B984B28E3363616563e11457a7498BB6;

    // Random signer address
    address internal _signer = 0xfeFf51Dd22131c2CB32E62E8e6032620a5142aFf;
    address internal _signer2 = 0xA9f6aE3502F75Ec8e0cd5463D96dC27E5e8F289a;

    function setUp() public virtual {
        // Deploy the SynthVault contract
        _synthVault =
            new SynthVaultPermit(_underlying, "Amphor Synthetic Vault", "ASV");

        _additionnalSetup();

        // if (true) {
        //     _decimalOffset = 1;
        // }
    }

    function _additionnalSetup() internal virtual { }

    function _getUnderlyingBalance(address user)
        internal
        view
        returns (uint256)
    {
        return IERC20(_synthVault.asset()).balanceOf(user);
    }

    function _getSharesBalance(address user) internal view returns (uint256) {
        return _synthVault.balanceOf(user);
    }

    function giveEthUnderlyingAndApprove(address user)
        public
        returns (uint256)
    {
        return giveEthUnderlyingAndApprove(
            user, 10_000 * 10 ** _underlyingDecimals
        );
    }

    function giveEthUnderlyingAndApprove(
        address user,
        uint256 amount
    )
        public
        returns (uint256)
    {
        hoax(user);
        deal(address(_underlying), user, amount);
        vm.prank(user);
        ERC20(_underlying).approve(address(_synthVault), UINT256_MAX);
        return amount;
    }

    function assertUnderlyingBalance(
        address owner,
        uint256 expectedBalance
    )
        public
    {
        assertEq(
            _getUnderlyingBalance(owner),
            expectedBalance,
            "underlying balance != expected balance"
        );
    }

    function assertSharesBalance(
        address owner,
        uint256 expectedBalance
    )
        public
    {
        assertEq(
            _getSharesBalance(owner),
            expectedBalance,
            "shares balance != expected balance"
        );
    }
}
