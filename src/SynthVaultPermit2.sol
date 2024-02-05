//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { SynthVault, ERC20 } from "./SynthVault.sol";
import {
    IPermit2, ISignatureTransfer
} from "permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    ISignatureTransfer.PermitTransferFrom permit;
    ISignatureTransfer.SignatureTransferDetails transferDetails;
    bytes signature;
}

contract SynthVaultPermit2 is SynthVault {
    // The canonical permit2 contract.
    IPermit2 public immutable permit2;

    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol,
        IPermit2 _permit2
    )
        SynthVault(underlying, name, symbol)
    {
        permit2 = _permit2;
    }

    // Deposit some amount of an ERC20 token into this contract
    // using Permit2.
    function execPermit2(Permit2Params calldata permit2Params) internal {
        // Transfer tokens from the caller to ourselves.
        permit2.permitTransferFrom(
            permit2Params.permit,
            permit2Params.transferDetails,
            _msgSender(),
            permit2Params.signature
        );
    }

    function requestDepositWithPermit2(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data,
        Permit2Params calldata permit2Params
    )
        external
    {
        if (_ASSET.allowance(owner, address(this)) < assets)
            execPermit2(permit2Params);
        return requestDeposit(assets, receiver, owner, data);
    }

    function depositWithPermit2(
        uint256 assets,
        address receiver,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < assets)
            execPermit2(permit2Params);
        return deposit(assets, receiver);
    }

    function depositWithPermit2MinShares(
        uint256 assets,
        address receiver,
        uint256 minShares,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < assets)
            execPermit2(permit2Params);
        return depositMinShares(assets, receiver, minShares);
    }

    function mintWithPermit2(
        uint256 shares,
        address receiver,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < previewMint(shares))
            execPermit2(permit2Params);
        return mint(shares, receiver);
    }

    function mintWithPermit2MaxAssets(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < previewMint(shares))
        {
            execPermit2(permit2Params);
        }
        return mintMaxAssets(shares, receiver, maxAssets);
    }
}
