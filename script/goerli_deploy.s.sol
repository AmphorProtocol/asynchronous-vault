// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { AsyncSynthVault } from "../src/AsyncSynthVault.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GOERLI_DeployAmphorSynthetic is Script {
    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        // string memory seedPhrase = vm.readFile(".secret");
        // uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        // IERC20 underlying = IERC20(vm.envAddress("AAVE_USDC_GOERLI"));
        // uint16 fees = uint16(vm.envUint("INITIAL_FEES_AMOUNT"));
        // string memory vaultName = vm.envString("SYNTHETIC_USDC_V1_NAME");
        // string memory vaultSymbol = vm.envString("SYNTHETIC_USDC_V1_SYMBOL");
        // IPermit2 permit2 = IPermit2(vm.envAddress("PERMIT2_ADDRESS"));
        // address owner = vm.envAddress("AMPHORLABS_ADDRESS");

        vm.startBroadcast(privateKey);

        // SynthVault vault = new SynthVault(
        //     fees, owner, underlying, vaultName, vaultSymbol, permit2
        // );

        // vault.setFee(fees);

        // // vault.transferOwnership(amphorlabsAddress);

        // console.log("Synthetic vault USDC contract address: ",
        // address(vault));

        // vm.stopBroadcast();

        //forge script script/goerli_deploy.s.sol:GOERLI_DeployAmphorSynthetic
        // --verifier-url ${VERIFIER_URL_GOERLI} --verify --broadcast
    }
}
