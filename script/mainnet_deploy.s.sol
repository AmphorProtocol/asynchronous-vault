// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { SynthVault } from "../src/SynthVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { UpgradeableBeacon } from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract GOERLI_DeployAmphorSynthetic is Script {
    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        // string memory seedPhrase = vm.readFile(".secret");
        // uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        uint16 fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        string memory vaultName = vm.envString("SYNTHETIC_USDC_V1_NAME");
        string memory vaultSymbol = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
        address owner = vm.envAddress("AMPHORLABS_ADDRESS");
        address underlying = vm.envAddress("USDC_MAINNET");
        address permit2 = vm.envAddress("PERMIT2");
        vm.startBroadcast(privateKey);

        address beacon = Upgrades.deployBeacon("SynthVault.sol", owner);

        address proxy = Upgrades.deployBeaconProxy(
            beacon,
            abi.encodeCall(
                SynthVault.initialize,
                (
                    fees,
                    owner,
                    IERC20(underlying),
                    vaultName,
                    vaultSymbol,
                    IPermit2(permit2)
                )
            )
        );

        address implementation = UpgradeableBeacon(beacon).implementation();
        console.log("Synthetic vault USDC contract address: ", proxy);
        console.log("Synthetic vault USDC beacon address: ", beacon);
        console.log(
            "Synthetic vault USDC implementation address: ", implementation
        );

        vm.stopBroadcast();

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
