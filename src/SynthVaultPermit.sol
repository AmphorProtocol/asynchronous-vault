//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {SynthVault, ERC20, ERC20Permit} from "./SynthVault.sol";

struct PermitParams {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract SynthVaultPermit is SynthVault {
    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol
    ) SynthVault(underlying, name, symbol) {}

    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data,
        PermitParams calldata permitParams
    ) external {
        if (_asset.allowance(owner, address(this)) < assets) {
            execPermit(owner, address(this), permitParams);
        }
        return super.requestDeposit(assets, receiver, owner, data);
    }

    function execPermit(
        address owner,
        address spender,
        PermitParams calldata permitParams
    ) internal {
        ERC20Permit(address(_asset)).permit(
            owner,
            spender,
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s
        );
    }
}
