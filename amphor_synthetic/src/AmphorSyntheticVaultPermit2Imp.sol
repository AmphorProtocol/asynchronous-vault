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
(  ____ \|\     /|( (    /|\__   __/|\     /|(  ____ \\__   __/\__   __/(  ____ \
| (    \/( \   / )|  \  ( |   ) (   | )   ( || (    \/   ) (      ) (   | (    \/
| (_____  \ (_) / |   \ | |   | |   | (___) || (__       | |      | |   | |
(_____  )  \   /  | (\ \) |   | |   |  ___  ||  __)      | |      | |   | |
      ) |   ) (   | | \   |   | |   | (   ) || (         | |      | |   | |
/\____) |   | |   | )  \  |   | |   | )   ( || (____/\   | |   ___) (___| (____/\
\_______)   \_/   |/    )_)   )_(   |/     \|(_______/   )_(   \_______/(_______/
*/

import "./AmphorSyntheticVaultImp.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IPermit2, ISignatureTransfer} from "@permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}

contract AmphorSyntheticVaultWithPermit2 is AmphorSyntheticVault {
    /*
     ####################################
      GENERAL PERMIT2 RELATED ATTRIBUTES
     ####################################
    */

    // The canonical permit2 contract.
    IPermit2 public immutable permit2;

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
        IPermit2 _permit2,
        AmprWithdrawReceipt _amprWithdrawReceipt
    ) AmphorSyntheticVault(underlying, oldShareToken, name, symbol, _decimalsOffset, _amprWithdrawReceipt) {
        permit2 = _permit2;
    }

    /*
     ##################
      PERMIT2 FUNCTION
     ##################
    */

    // Deposit some amount of an ERC20 token into this contract
    // using Permit2.
    function execPermit2(
        Permit2Params calldata permit2Params
    ) internal {
        // Transfer tokens from the caller to ourselves.
        permit2.permitTransferFrom(
            // The permit message.
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: permit2Params.token,
                    amount: permit2Params.amount
                }),
                nonce: permit2Params.nonce,
                deadline: permit2Params.deadline
            }),
            // The transfer recipient and amount.
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: permit2Params.amount
            }),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            _msgSender(),
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            permit2Params.signature
        );
    }

    function depositWithPermit2(
        uint256 assets,
        address receiver,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        execPermit2(permit2Params);
        return deposit(assets, receiver);
    }

    /*
     * @dev The `depositWithPermitMinShares` function is used to deposit
     * underlying assets into the vault using a permit for approval.
     * @param assets The underlying assets amount to be converted into
     * shares.
     * @param receiver The address of the shares receiver.
     * @param minShares The minimum amount of shares to be received in exchange of
     * the specified underlying assets amount.
     * @param permitParams The permit struct containing the permit signature and data.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
    */
    function depositWithPermit2MinShares(
        uint256 assets,
        address receiver,
        uint256 minShares,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        execPermit2(permit2Params);
        return depositMinShares(assets, receiver, minShares);
    }

    function mintWithPermit2(
        uint256 shares,
        address receiver,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        execPermit2(permit2Params);
        return mint(shares, receiver);
    }
    
    function mintWithPermit2MaxAssets(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        execPermit2(permit2Params);
        return mintMaxAssets(shares, receiver, maxAssets);
    }

    function buyWithPermit2(
        address buyer,
        address receiver,
        uint256 sharesAmount,
        uint256 underlyingAmount,
        SignatureParams calldata signatureParams,
        Permit2Params calldata permit2Params
    ) external {
        execPermit2(permit2Params);
        buy(buyer, receiver, sharesAmount, underlyingAmount, signatureParams);
    }

}