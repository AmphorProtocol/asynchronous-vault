//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SynthVaultPermit, SynthVault } from "../../src/SynthVaultPermit.sol";
import { SynthVaultPermit2, IPermit2 } from "../../src/SynthVaultPermit2.sol";
import { AsyncVaultZapper } from "../../src/AsyncVaultZapper.sol";
import { VmSafe } from "forge-std/Vm.sol";

abstract contract Constants is Test {
    // ERC20 tokens
    ERC20 immutable DAI = ERC20(vm.envAddress("DAI_MAINNET"));
    ERC20 immutable USDC = ERC20(vm.envAddress("USDC_MAINNET"));
    ERC20 immutable USDT = ERC20(vm.envAddress("USDT_MAINNET"));
    ERC20 immutable WETH = ERC20(vm.envAddress("WETH_MAINNET"));
    ERC20 immutable ETH = ERC20(vm.envAddress("ETH_MAINNET"));
    ERC20 immutable WSTETH = ERC20(vm.envAddress("WSTETH_MAINNET"));
    ERC20 immutable STETH = ERC20(vm.envAddress("STETH_MAINNET"));
    ERC20 immutable WBTC = ERC20(vm.envAddress("WBTC_MAINNET"));

    // Future Owner
    address immutable amphorLabs = vm.envAddress("AMPHORLABS_ADDRESS");

    // Permit2
    IPermit2 immutable permit2 = IPermit2(vm.envAddress("PERMIT2"));

    // USDC vault
    string vaultNameUSDC = vm.envString("SYNTHETIC_USDC_V1_NAME");
    string vaultSymbolUSDC = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
    SynthVaultPermit immutable vaultUSDC =
        new SynthVaultPermit(USDC, vaultNameUSDC, vaultSymbolUSDC);

    // WSTETH vault
    string vaultNameWSTETH = vm.envString("SYNTHETIC_WSTETH_V1_NAME");
    string vaultSymbolWSTETH = vm.envString("SYNTHETIC_WSTETH_V1_SYMBOL");
    SynthVaultPermit immutable vaultWSTETH =
        new SynthVaultPermit(WSTETH, vaultNameWSTETH, vaultSymbolWSTETH);

    // WBTC vault
    string vaultNameWBTC = vm.envString("SYNTHETIC_WBTC_V1_NAME");
    string vaultSymbolWBTC = vm.envString("SYNTHETIC_WBTC_V1_SYMBOL");
    SynthVaultPermit2 immutable vaultWBTC =
        new SynthVaultPermit2(WBTC, vaultNameWBTC, vaultSymbolWBTC, permit2);

    // Zapper
    AsyncVaultZapper immutable zapper = new AsyncVaultZapper(permit2);

    // Users
    VmSafe.Wallet user1 = vm.createWallet("user1");
    VmSafe.Wallet user2 = vm.createWallet("user2");
    VmSafe.Wallet user3 = vm.createWallet("user3");
    VmSafe.Wallet user4 = vm.createWallet("user4");
    VmSafe.Wallet user5 = vm.createWallet("user5");
    VmSafe.Wallet user6 = vm.createWallet("user6");
    VmSafe.Wallet user7 = vm.createWallet("user7");
    VmSafe.Wallet user8 = vm.createWallet("user8");
    VmSafe.Wallet user9 = vm.createWallet("user9");
    VmSafe.Wallet user10 = vm.createWallet("user10");

    VmSafe.Wallet[] users;

    constructor() {
        vm.label(address(DAI), "DAI");
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(address(WETH), "WETH");
        vm.label(address(ETH), "ETH");
        vm.label(address(WSTETH), "WSTETH");
        vm.label(address(STETH), "STETH");
        vm.label(address(WBTC), "WBTC");

        vm.label(address(amphorLabs), "amphorLabs");
        vm.label(address(permit2), "permit2");

        vm.label(address(vaultUSDC), "vaultUSDC");
        vm.label(address(vaultWSTETH), "vaultWSTETH");
        vm.label(address(vaultWBTC), "vaultWBTC");

        vm.label(address(zapper), "zapper");

        users.push(user1);
        users.push(user2);
        users.push(user3);
        users.push(user4);
        users.push(user5);
        users.push(user6);
        users.push(user7);
        users.push(user8);
        users.push(user9);
        users.push(user10);
    }
}
