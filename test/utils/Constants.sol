//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;


import { Test } from "forge-std/Test.sol";
import { ERC20 } from
    "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SynthVaultPermit, SynthVault } from "../../src/SynthVaultPermit.sol";
import { SynthVaultPermit2, IPermit2 } from "../../src/SynthVaultPermit2.sol";
import { AsyncVaultZapper } from "../../src/AsyncVaultZapper.sol";

abstract contract Constants is Test {
    // ERC20 tokens
    ERC20 internal immutable _DAI = ERC20(vm.envAddress("DAI_MAINNET"));
    ERC20 internal immutable _USDC = ERC20(vm.envAddress("USDC_MAINNET"));
    ERC20 internal immutable _USDT = ERC20(vm.envAddress("USDT_MAINNET"));
    ERC20 internal immutable _WETH = ERC20(vm.envAddress("WETH_MAINNET"));
    ERC20 internal immutable _ETH = ERC20(vm.envAddress("ETH_MAINNET"));
    ERC20 internal immutable _WSTETH = ERC20(vm.envAddress("WSTETH_MAINNET"));
    ERC20 internal immutable _STETH = ERC20(vm.envAddress("STETH_MAINNET"));
    ERC20 internal immutable _WBTC = ERC20(vm.envAddress("WBTC_MAINNET"));

    ERC20 internal immutable _underlying;

    address internal immutable _amphorLabs = vm.envAddress("AMPHORLABS_ADDRESS");

    // Permit2
    IPermit2 internal immutable _permit2 = IPermit2(vm.envAddress("PERMIT2_ADDRESS"));

    // USDC vault
    string internal _vaultNameUSDC = vm.envString("SYNTHETIC_USDC_V1_NAME");
    string internal _vaultSymbolUSDC = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
    SynthVaultPermit internal immutable _vaultUSDC = new SynthVaultPermit(
        _USDC,
        _vaultNameUSDC,
        _vaultSymbolUSDC
    );

    // WSTETH vault
    string internal _vaultNameWSTETH = vm.envString("SYNTHETIC_WSTETH_V1_NAME");
    string internal _vaultSymbolWSTETH = vm.envString("SYNTHETIC_WSTETH_V1_SYMBOL");
    SynthVaultPermit internal immutable _vaultWSTETH = new SynthVaultPermit(
        _WSTETH,
        _vaultNameWSTETH,
        _vaultSymbolWSTETH
    );

    // WBTC vault
    string internal _vaultNameWBTC = vm.envString("SYNTHETIC_WBTC_V1_NAME");
    string internal _vaultSymbolWBTC = vm.envString("SYNTHETIC_WBTC_V1_SYMBOL");
    SynthVaultPermit2 internal immutable _vaultWBTC = new SynthVaultPermit2(
        _WBTC,
        _vaultNameWBTC,
        _vaultSymbolWBTC,
        _permit2
    );

    // Zapper
    AsyncVaultZapper internal immutable _zapper = new AsyncVaultZapper(
        _permit2
    );
}