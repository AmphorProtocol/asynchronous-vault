//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/*
 _______  _______  _______           _______  _______
(  ___  )(       )(  ____ )|\     /|(  ___  )(  ____ )
| (   ) || () () || (    )|| )   ( || (   ) || (    )|
| (___) || || || || (____)|| (___) || |   | || (____)|
|  ___  || |(_)| ||  _____)|  ___  || |   | ||     __)
| (   ) || |   | || (      | (   ) || |   | || (\ (
| )   ( || )   ( || )      | )   ( || (___) || ) \ \__
|/     \||/     \||/       |/     \|(_______)|/   \__/
 _______           _       _________          _______ __________________ _______
(  ____ \|\     /|( (    /|\__   __/|\     /|(  ____ \\__   __/\__   __/(  ____
\
| (    \/( \   / )|  \  ( |   ) (   | )   ( || (    \/   ) (      ) (   | (    \/
| (_____  \ (_) / |   \ | |   | |   | (___) || (__       | |      | |   | |
(_____  )  \   /  | (\ \) |   | |   |  ___  ||  __)      | |      | |   | |
      ) |   ) (   | | \   |   | |   | (   ) || (         | |      | |   | |
/\____) |   | |   | )  \  |   | |   | )   ( || (____/\   | |   ___) (___|
(____/\
\_______)   \_/   |/    )_)   )_(   |/     \|(_______/   )_(   \_______/(_______/*/

import "./AmphorSyntheticVaultImp.sol";

/*
 * @dev The `PermitParams` struct is used to pass the permit signature and data.
 * @param value The amount of tokens the spender is allowed to spend.
 * @param deadline The timestamp after which the permit is no longer valid.
 * @param v The recovery byte of the permit signature.
 * @param r Half of the ECDSA signature pair of the permit.
 * @param s Half of the ECDSA signature pair of the permit.
 */
struct PermitParams {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract AmphorSyntheticVaultPermitImp is AmphorSyntheticVaultImp {
    /**
     * @dev The `constructor` function is used to initialize the vault.
     * @param underlying The underlying asset token.
     * @param name The name of the vault.
     * @param symbol The symbol of the vault.
     * @param _decimalsOffset The decimal offset between the asset token and the
     * share token.
     */
    constructor(
        ERC20 underlying,
        ERC20 oldShareToken,
        string memory name,
        string memory symbol,
        uint8 _decimalsOffset,
        AmprWithdrawReceipt _amprWithdrawReceipt
    )
        AmphorSyntheticVaultImp(
            underlying,
            oldShareToken,
            name,
            symbol,
            _decimalsOffset,
            _amprWithdrawReceipt
        )
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
        if (_asset.allowance(msg.sender, address(this)) < assets) {
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
        if (_asset.allowance(msg.sender, address(this)) < assets) {
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
        if (_asset.allowance(msg.sender, address(this)) < previewMint(shares)) {
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
        if (_asset.allowance(msg.sender, address(this)) < previewMint(shares)) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return mintMaxAssets(shares, receiver, maxAssets);
    }

    /*
    * @dev The `execPermit` function is used to execute a permit for approval.
     * @param owner The owner of the funds.
     * @param spender The spender of the funds.
    * @param permitParams The permit struct containing the permit signature and
    data.
     */
    function execPermit(
        address owner,
        address spender,
        PermitParams calldata permitParams
    )
        internal
    {
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
