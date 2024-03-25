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
    string vaultName;
    string vaultSymbol;
    address owner;
    address underlying;
    address permit2;
    uint256 bootstrap;
    uint256 nonce; // beacon deployment + approve
    Options deploy;

    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        privateKey = vm.envUint("PRIVATE_KEY");
        fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        vaultName = vm.envString("SYNTHETIC_USDC_V1_NAME");
        vaultSymbol = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
        owner = vm.envAddress("AMPHORLABS_ADDRESS");
        underlying = vm.envAddress("USDC_MAINNET");
        permit2 = vm.envAddress("PERMIT2");
        bootstrap = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_USDC");

        vm.startBroadcast(privateKey);

        UpgradeableBeacon beacon = UpgradeableBeacon(
            Upgrades.deployBeacon("AsyncVault.sol", owner, deploy)
        );

        BeaconProxy proxy = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(
                        AsyncVault.initialize,
                        (
                            fees,
                            owner,
                            IERC20(underlying),
                            bootstrap,
                            vaultName,
                            vaultSymbol
                        )
                    )
                )
            )
        );

        address implementation = UpgradeableBeacon(beacon).implementation();
        console.log("Synthetic vault USDC proxy address: ", address(proxy));
        console.log("Synthetic vault USDC beacon address: ", address(beacon));
        console.log(
            "Synthetic vault USDC implementation address: ", implementation
        );

        IERC20(underlying).transfer(address(proxy), bootstrap);

        vm.stopBroadcast();

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
