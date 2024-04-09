// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { AsyncVault } from "../src/AsyncVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { UpgradeableBeacon } from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BeaconProxy } from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { VaultZapper } from "../src/VaultZapper.sol";

contract Local_deploy is Script {
    uint256 privateKey;
    uint16 fees;
    string vaultName;
    string vaultSymbol;
    address owner;
    address underlying;
    address router;
    uint256 bootstrap;
    uint256 nonce; // beacon deployment + approve
    Options deploy;

    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        privateKey = vm.envUint("PRIVATE_KEY");

        owner = vm.envAddress("AMPHORLABS_ADDRESS");
        router = vm.envAddress("ONE_INCH_ROUTER_V5");
        owner = vm.addr(privateKey);
        fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        vaultName = vm.envString("SYNTHETIC_WETH_V1_NAME");
        vaultSymbol = vm.envString("SYNTHETIC_WETH_V1_SYMBOL");
        underlying = vm.envAddress("WETH_MAINNET");
        bootstrap = 0;
        nonce = vm.getNonce(owner);
        // address nextProxyAddress = vm.computeCreateAddress(owner, nonce + 1);
        vm.startBroadcast(privateKey);

        AsyncVault asyncVault = new AsyncVault();
        IERC20(underlying).approve(address(asyncVault), UINT256_MAX);

        asyncVault.initialize(
            fees,
            owner,
            owner,
            IERC20(underlying),
            bootstrap,
            vaultName,
            vaultSymbol
        );

        VaultZapper vaultZapper = new VaultZapper();
        vaultZapper.toggleVaultAuthorization(asyncVault);
        vaultZapper.toggleRouterAuthorization(router);

        vm.stopBroadcast();
        console.log("Synthetic vault address: ", address(asyncVault));
        console.log("Vault zapper address: ", address(vaultZapper));
        // uint256 ownerUnderlyingBalance = IERC20(underlying).balanceOf(owner);
        // uint256 ownerVaultBalance =
        // IERC20(address(asyncVault)).balanceOf(owner);
        // uint256 totalAssets = asyncVault.totalAssets();
        // console.log("Owner underlying balance: ", ownerUnderlyingBalance);
        // console.log("Owner vault balance: ", ownerVaultBalance);

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
