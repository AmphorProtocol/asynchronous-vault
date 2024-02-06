//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { SynthVault, IPermit2 } from "../../src/SynthVault.sol";
import "forge-std/console.sol"; //todo remove

contract SynthVault2 is SynthVault {
    uint256 public newVariable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IPermit2 _permit2) SynthVault(_permit2) {
        _disableInitializers();
    }

    function initialize(uint256 _newVariable)
        public
        onlyOwner
        reinitializer(2)
    {
        newVariable = _newVariable;
    }

    function getNewVariable() public view returns (uint256) {
        return newVariable;
    }
}