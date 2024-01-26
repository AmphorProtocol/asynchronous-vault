// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../../../lib/forge-std/src/console.sol";
import "../../../lib/forge-std/src/Test.sol";

import {
    ERC4626,
    IERC4626
} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import "../../../src/SynthVaultPermit.sol";

abstract contract GlobalTest is Test {
    ERC20 internal immutable _DAI = ERC20(vm.envAddress("DAI_MAINNET"));
    ERC20 internal immutable _USDC = ERC20(vm.envAddress("DAI_MAINNET"));
    ERC20 internal immutable _USDT = ERC20(vm.envAddress("USDT_MAINNET"));
    ERC20 internal immutable _WETH = ERC20(vm.envAddress("WETH_MAINNET"));
    ERC20 internal immutable _ETH = ERC20(vm.envAddress("ETH_MAINNET"));
    ERC20 internal immutable _WSTETH = ERC20(vm.envAddress("WSTETH_MAINNET"));
    ERC20 internal immutable _STETH = ERC20(vm.envAddress("STETH_MAINNET"));
    ERC20 internal immutable _WBTC = ERC20(vm.envAddress("WBTC_MAINNET"));

    ERC20 internal _underlying;

    IERC4626 internal _vault;

    uint256[] _usersPk = [
        0xA11CE,
        0x1CEA11,
        0x1CEA12,
        0x1CEA13,
        0x1CEA14,
        0x1CEA15,
        0x1CEA16,
        0x1CEA17,
        0x1CEA18,
        0x1CEA19
    ];
    // address[] internal _users;

    address[] internal _users = [
        vm.addr(_usersPk[0]),
        vm.addr(_usersPk[1]),
        vm.addr(_usersPk[2]),
        vm.addr(_usersPk[3]),
        vm.addr(_usersPk[4]),
        vm.addr(_usersPk[5]),
        vm.addr(_usersPk[6]),
        vm.addr(_usersPk[7]),
        vm.addr(_usersPk[8]),
        vm.addr(_usersPk[9])
    ];

    uint256 internal _bootstrapAmount;
    uint256 internal _initialMintAmount;
    uint256 internal _vaultDecimals;
    address internal _amphorLabs;
    string internal _vaultName;
    string internal _vaultSymbol;
}
