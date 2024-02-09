//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { AsyncSynthVault } from "../AsyncSynthVault.sol";
import "forge-std/console.sol"; //todo remove
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";

contract AsyncSynthVault2 is AsyncSynthVault {
    uint256 public newVariable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IPermit2 _permit2) AsyncSynthVault(_permit2) {
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
