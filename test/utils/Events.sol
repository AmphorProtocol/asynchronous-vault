//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC7540 } from "../../src/interfaces/IERC7540.sol";

abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                    ERC-20
    //////////////////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner, address indexed spender, uint256 value
    );

    /*//////////////////////////////////////////////////////////////////////////
                                    ERC-4626
    //////////////////////////////////////////////////////////////////////////*/
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 share
    );

    /*//////////////////////////////////////////////////////////////////////////
                                    ERC-7540
    //////////////////////////////////////////////////////////////////////////*/
    event DepositRequest(
        address indexed receiver,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    event RedeemRequest(
        address indexed receiver,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////////////////
                                Amphor Base Vault
    //////////////////////////////////////////////////////////////////////////*/
    event EpochStart(
        uint256 indexed timestamp, uint256 lastSavedBalance, uint256 totalShares
    );

    event EpochEnd(
        uint256 indexed timestamp,
        uint256 lastSavedBalance,
        uint256 returnedAssets,
        uint256 fees,
        uint256 totalShares
    );

    event FeesChanged(uint16 oldFees, uint16 newFees);

    event AsyncDeposit(
        uint256 indexed requestId,
        uint256 requestedAssets,
        uint256 acceptedAssets
    );

    event AsyncWithdraw(
        uint256 indexed requestId,
        uint256 requestedShares,
        uint256 acceptedShares
    );

    event DecreaseDepositRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedAssets,
        uint256 newRequestedAssets
    );

    event DecreaseRedeemRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedShares,
        uint256 newRequestedShares
    );

    event ClaimDeposit(
        uint256 indexed requestId,
        address indexed caller,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    event ClaimRedeem(
        uint256 indexed requestId,
        address indexed caller,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////////////////
                                    Zapper
    //////////////////////////////////////////////////////////////////////////*/
    event ZapAndRequestDeposit(
        IERC7540 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount
    );

    event ClaimRedeemAndZap(
        IERC7540 indexed vault,
        address indexed router,
        uint256 shares,
        uint256 assets
    );

    event routerApproved(address indexed router, IERC20 indexed token);

    event routerAuthorized(address indexed router, bool allowed);

    event vaultAuthorized(IERC7540 indexed vault, bool allowed);
}
