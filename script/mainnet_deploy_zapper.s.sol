// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { VaultZapper } from "../src/VaultZapper.sol";
import { AsyncVault } from "../src/AsyncVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MAINNET_DeployAmphorZapper is Script {
    uint256 privateKey;
    address owner;
    address amphor;
    address router;

    function run() external {
        // if you want to deploy a vault with a seed phrase instead of a pk,
        // uncomment the following line
        privateKey = vm.envUint("PRIVATE_KEY");
        router = vm.envAddress("ONE_INCH_ROUTER_V5");

        amphor = vm.envAddress("AMPHORLABS_ADDRESS");
        owner = vm.addr(privateKey);
        vm.startBroadcast(privateKey);
        VaultZapper zapper = new VaultZapper();
        zapper.toggleVaultAuthorization(
            AsyncVault(0xcDC51F2B0e5F0906f2fd5f557de49D99c34Df54e)
        );
        zapper.toggleRouterAuthorization(router);

        zapper.transferOwnership(amphor);

        console.log("Zapper address: ", address(zapper));

        vm.stopBroadcast();

        // Mainnet 
        // source .env && forge clean && forge script script/mainnet_deploy_zapper.s.sol:MAINNET_DeployAmphorZapper --ffi --chain-id 1 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
        // Sepolia
        // source .env && forge clean && forge script script/mainnet_deploy_zapper.s.sol:MAINNET_DeployAmphorZapper --ffi --chain-id 534351 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL_SEPOLIA} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
    }
}
