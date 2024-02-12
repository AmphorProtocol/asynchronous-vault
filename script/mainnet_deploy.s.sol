// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { AsyncSynthVault } from "../src/AsyncSynthVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { UpgradeableBeacon } from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BeaconProxy } from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract GOERLI_DeployAmphorSynthetic is Script {
    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        uint16 fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        string memory vaultName = vm.envString("SYNTHETIC_USDC_V1_NAME");
        string memory vaultSymbol = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
        address owner = vm.envAddress("AMPHORLABS_ADDRESS");
        address underlying = vm.envAddress("USDC_MAINNET");
        address permit2 = vm.envAddress("PERMIT2");
        vm.startBroadcast(privateKey);

        Options memory deploy;
        deploy.constructorData = abi.encode(permit2);
        UpgradeableBeacon beacon = UpgradeableBeacon(
            Upgrades.deployBeacon("AsyncSynthVault.sol", owner, deploy)
        );

        BeaconProxy proxy = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(
                        AsyncSynthVault.initialize,
                        (
                            fees,
                            owner,
                            IERC20(underlying),
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

        vm.stopBroadcast();

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
