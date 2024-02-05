// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import { BeaconProxy } from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { SynthVaultPermit } from "../SynthVaultPermit.sol";

contract AmphorBeaconProxy is BeaconProxy {
    constructor(address beacon, bytes memory data) BeaconProxy(beacon, data) { }
}
