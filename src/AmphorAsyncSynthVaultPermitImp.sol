//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {AmphorAsyncSynthVaultImp, ERC20, ERC20Permit} from "./AmphorAsyncSynthVaultImp.sol";

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

contract AsyncVaultPermitImp is AmphorAsyncSynthVaultImp {

    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol,
        string memory depositRequestLPName,
        string memory depositRequestLPSymbol,
        string memory withdrawRequestLPName,
        string memory withdrawRequestLPSymbol
    ) AmphorAsyncSynthVaultImp(underlying, name, symbol, depositRequestLPName, depositRequestLPSymbol, withdrawRequestLPName, withdrawRequestLPSymbol) {}

    /**
     * @dev The `requestDepositWithPermit` function is used to request a deposit
     * using a permit for approval.
     * @param assets The underlying assets amount to be converted into
     * shares.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the shares owner.
     * @param permitParams The permit struct containing the permit signature and data.
     */
    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        address owner,
        PermitParams calldata permitParams
    ) external {
        if (_asset.allowance(owner, address(this)) < assets)
            execPermit(owner, address(this), permitParams);
        return super.requestDeposit(assets, receiver, owner);
    }

    /*
     * @dev The `execPermit` function is used to execute a permit for approval.
     * @param owner The owner of the funds.
     * @param spender The spender of the funds.
     * @param permitParams The permit struct containing the permit signature and data.
     */
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