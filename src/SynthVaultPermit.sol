//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { SynthVault, ERC20, ERC20Permit } from "./SynthVault.sol";

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
    )
        SynthVault(underlying, name, symbol)
    { }

    /**
     * @dev The `depositWithPermit` function is used to deposit underlying
     * assets
     * into the vault using a permit for approval.
     * @param assets The underlying assets amount to be converted into
     * shares.
     * @param receiver The address of the shares receiver.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function depositWithPermit(
        uint256 assets,
        address receiver,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < assets) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return deposit(assets, receiver);
    }

    /*
     * @dev The `depositWithPermitMinShares` function is used to deposit
     * underlying assets into the vault using a permit for approval.
     * @param assets The underlying assets amount to be converted into
     * shares.
     * @param receiver The address of the shares receiver.
    * @param minShares The minimum amount of shares to be received in exchange
    of
     * the specified underlying assets amount.
    * @param permitParams The permit struct containing the permit signature and
    data.
    * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function depositWithPermitMinShares(
        uint256 assets,
        address receiver,
        uint256 minShares,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < assets) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return depositMinShares(assets, receiver, minShares);
    }

    /**
     * @dev The `mintWithPermit` function is used to mint the specified shares
     * amount in exchange of the corresponding underlying assets amount from
     * `_msgSender()` using a permit for approval.
     * @param shares The amount of shares to be converted into underlying
     * assets.
     * @param receiver The address of the shares receiver.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of underlying assets deposited in exchange of the
     * specified
     * shares amount.
     */
    function mintWithPermit(
        uint256 shares,
        address receiver,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < previewMint(shares)) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return mint(shares, receiver);
    }

    /**
     * @dev The `mintWithPermit` function is used to mint the specified shares
     * amount in exchange of the corresponding underlying assets amount from
     * `_msgSender()` using a permit for approval.
     * @param shares The amount of shares to be converted into underlying
     * assets.
     * @param receiver The address of the shares receiver.
     * @param maxAssets The maximum amount of underlying assets to be deposited
     * in exchange of the specified shares amount.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of underlying assets deposited in exchange of the
     * specified
     * shares amount.
     */
    function mintWithPermitMaxAssets(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < previewMint(shares)) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return mintMaxAssets(shares, receiver, maxAssets);
    }

    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data,
        PermitParams calldata permitParams
    )
        external
    {
        if (_ASSET.allowance(owner, address(this)) < assets) {
            execPermit(owner, address(this), permitParams);
        }
        return super.requestDeposit(assets, receiver, owner, data);
    }

    function execPermit(
        address owner,
        address spender,
        PermitParams calldata permitParams
    )
        internal
    {
        ERC20Permit(address(_ASSET)).permit(
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
