// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { SynthVault2, SynthVault } from "../../src/else/SynthVault2.sol";
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
        // string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privateKey);
        uint16 fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        string memory vaultName = vm.envString("SYNTHETIC_USDC_V1_NAME");
        string memory vaultSymbol = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
        address underlying = vm.envAddress("USDC_MAINNET");
        address permit2 = vm.envAddress("PERMIT2");
        vm.startBroadcast(privateKey);

        Options memory deploy;
        deploy.constructorData = abi.encode(permit2);
        UpgradeableBeacon beacon = UpgradeableBeacon(
            Upgrades.deployBeacon("SynthVault.sol", owner, deploy)
        );

        BeaconProxy proxy = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(
                        SynthVault.initialize,
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
        console.log("Synthetic vault USDC contract address: ", address(proxy));
        console.log("Synthetic vault USDC beacon address: ", address(beacon));
        console.log(
            "Synthetic vault USDC implementation address: ", implementation
        );

        Options memory upgrade;
        upgrade.referenceContract = "SynthVault2.sol";
        upgrade.constructorData = abi.encode(permit2);
        Upgrades.upgradeBeacon(address(beacon), "SynthVault2.sol", upgrade);
        SynthVault2(address(proxy)).initialize(42);

        address newImplInBeacon = UpgradeableBeacon(beacon).implementation();
        uint256 variable = SynthVault2(address(proxy)).newVariable();
        uint256 variableInImpl =
            SynthVault2(address(newImplInBeacon)).newVariable();

        console.log("Synthetic vault USDC new variable in proxy: ", variable);
        console.log(
            "Synthetic vault USDC new variable in new implementation: ",
            variableInImpl
        );
        console.log(
            "Synthetic vault USDC new implementation address: ", newImplInBeacon
        );
        vm.stopBroadcast();

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
