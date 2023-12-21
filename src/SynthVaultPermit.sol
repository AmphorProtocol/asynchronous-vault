//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// import {SynthVault, ERC20, ERC20Permit, IPermit2} from "./SynthVault.sol";

// struct PermitParams {
//     uint256 value;
//     uint256 deadline;
//     uint8 v;
//     bytes32 r;
//     bytes32 s;
// }

// contract SynthVaultPermit is SynthVault {

//     constructor(
//         ERC20 underlying,
//         string memory name,
//         string memory symbol,
//         string memory depositRequestLPName,
//         string memory depositRequestLPSymbol,
//         string memory withdrawRequestLPName,
//         string memory withdrawRequestLPSymbol,
//         IPermit2 _permit2
//     ) SynthVault(underlying, name, symbol, depositRequestLPName, depositRequestLPSymbol, withdrawRequestLPName, withdrawRequestLPSymbol, _permit2) {}

//     function requestDepositWithPermit(
//         uint256 assets,
//         address receiver,
//         address owner,
//         PermitParams calldata permitParams
//     ) external {
//         if (_asset.allowance(owner, address(this)) < assets)
//             execPermit(owner, address(this), permitParams);
//         return super.requestDeposit(assets, receiver, owner);
//     }

//     function execPermit(
//         address owner,
//         address spender,
//         PermitParams calldata permitParams
//     ) internal {
//         ERC20Permit(address(_asset)).permit(
//             owner,
//             spender,
//             permitParams.value,
//             permitParams.deadline,
//             permitParams.v,
//             permitParams.r,
//             permitParams.s
//         );
//     }
// }
