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

contract MAINNET_DeployAmphorSynthetic is Script {
    uint256 privateKey;
    uint16 fees;
    string vaultNameUSDC;
    string vaultNameWETH;
    string vaultSymbolUSDC;
    string vaultSymbolWETH;
    address owner;
    address usdcAddr;
    address wethAddr;
    uint256 bootstrapUSDC;
    uint256 bootstrapWETH;
    uint256 nonce; // beacon deployment + approve
    Options deploy;

    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        privateKey = vm.envUint("PRIVATE_KEY");

        owner = vm.envAddress("AMPHORLABS_ADDRESS");
        owner = vm.addr(privateKey);
        fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        vaultNameUSDC = vm.envString("SYNTHETIC_USDC_V1_NAME");
        vaultSymbolUSDC = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
        usdcAddr = vm.envAddress("USDC_MAINNET");
        bootstrapUSDC = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_WETH");
        vaultNameWETH = vm.envString("SYNTHETIC_WETH_V1_NAME");
        vaultSymbolWETH = vm.envString("SYNTHETIC_WETH_V1_SYMBOL");
        wethAddr = vm.envAddress("WETH_MAINNET");
        bootstrapWETH = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_WETH");
        nonce = vm.getNonce(owner);
        address usdcProxyAddress = vm.computeCreateAddress(owner, nonce + 4);
        address wethProxyAddress = vm.computeCreateAddress(owner, nonce + 5);
        vm.startBroadcast(privateKey);

        IERC20(usdcAddr).approve(usdcProxyAddress, UINT256_MAX);
        IERC20(wethAddr).approve(wethProxyAddress, UINT256_MAX);

        UpgradeableBeacon beacon = UpgradeableBeacon(
            Upgrades.deployBeacon("AsyncVault.sol:AsyncVault", owner, deploy)
        );

        BeaconProxy proxyUSDC = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(
                        AsyncVault.initialize,
                        (
                            fees,
                            owner,
                            owner,
                            IERC20(usdcAddr),
                            bootstrapUSDC,
                            vaultNameUSDC,
                            vaultSymbolUSDC
                        )
                    )
                )
            )
        );

        BeaconProxy proxyWETH = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(
                        AsyncVault.initialize,
                        (
                            fees,
                            owner,
                            owner,
                            IERC20(wethAddr),
                            bootstrapWETH,
                            vaultNameWETH,
                            vaultSymbolWETH
                        )
                    )
                )
            )
        );

        address implementation = UpgradeableBeacon(beacon).implementation();
        console.log("Vault USDC proxy address: ", address(proxyUSDC));
        console.log("Vault WETH proxy address: ", address(proxyWETH));

        console.log("Vault beacon address: ", address(beacon));
        console.log(
            "Vault implementation address: ", implementation
        );

        vm.stopBroadcast();

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
