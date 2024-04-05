// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { AsyncVault } from "../src/AsyncVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { UpgradeableBeacon } from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BeaconProxy } from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract MAINNET_DeployAmphor is Script {
    uint256 privateKey;
    uint16 fees;
    string vaultNameUSDC;
    string vaultNameWETH;
    string vaultSymbolUSDC;
    string vaultSymbolWETH;
    address owner;
    address usdcAddr;
    address wethAddr;
    address amphor;
    uint256 bootstrapUSDC;
    uint256 bootstrapWETH;
    uint256 nonce; // beacon deployment + approve
    Options deploy;

    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        privateKey = vm.envUint("PRIVATE_KEY");
        amphor = vm.envAddress("AMPHORLABS_ADDRESS");
        owner = vm.addr(privateKey);
        fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        vaultNameUSDC = vm.envString("USDC_V1_NAME");
        vaultSymbolUSDC = vm.envString("USDC_V1_SYMBOL");
        usdcAddr = vm.envAddress("USDC_MAINNET");
        bootstrapUSDC = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_USDC");
        vaultNameWETH = vm.envString("WETH_V1_NAME");
        vaultSymbolWETH = vm.envString("WETH_V1_SYMBOL");
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

        AsyncVault(address(proxyUSDC)).transferOwnership(amphor);
        AsyncVault(address(proxyWETH)).transferOwnership(amphor);

        address implementation = UpgradeableBeacon(beacon).implementation();
        console.log("Vault USDC proxy address: ", address(proxyUSDC));
        console.log("Vault WETH proxy address: ", address(proxyWETH));

        console.log("Vault beacon address: ", address(beacon));
        console.log(
            "Vault implementation address: ", implementation
        );

        vm.stopBroadcast();

        // Mainnet 
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id 1 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
        // Sepolia
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id 534351 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL_SEPOLIA} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
    }
}
