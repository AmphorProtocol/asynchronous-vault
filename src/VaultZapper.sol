//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC7540, IERC4626 } from "./interfaces/IERC7540.sol";
import { PermitParams } from "./AsyncSynthVault.sol";
import { ERC20Permit } from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import {
    IPermit2, ISignatureTransfer
} from "permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}

contract VaultZapper is Ownable2Step, Pausable {
    /**
     * @dev The `SafeERC20` lib is only used for `safeTransfer`,
     * `safeTransferFrom` and `forceApprove` operations.
     */
    using SafeERC20 for IERC20;

    /**
     * @dev The `Address` lib is only used for `sendValue` operations.
     */
    using Address for address payable;

    mapping(IERC4626 vault => bool isAuthorized) public authorizedVaults;
    mapping(address routerAddress => bool isAuthorized) public authorizedRouters;

    // The canonical permit2 contract.
    IPermit2 public immutable PERMIT2;

    event ZapAndRequestDeposit(
        IERC7540 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount
    );
    event ZapAndDeposit(
        IERC4626 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount,
        uint256 shares
    );
    event ClaimRedeemAndZap(
        IERC7540 indexed vault,
        address indexed router,
        uint256 shares,
        uint256 assets
    );
    event RouterApproved(address indexed router, IERC20 indexed token);
    event RouterAuthorized(address indexed router, bool allowed);
    event VaultAuthorized(IERC4626 indexed vault, bool allowed);

    error NotRouter(address router);
    error NotVault(IERC4626 vault);
    error SwapFailed(string reason);
    error InconsistantSwapData(
        uint256 expectedTokenInBalance, uint256 actualTokenInBalance
    );
    error NotEnoughSharesMinted(uint256 sharesMinted, uint256 minSharesMinted);
    error NotEnoughUnderlying(
        uint256 previewedUnderlying, uint256 withdrawedUnderlying
    );
    error NullMinShares();

    modifier onlyAllowedRouter(address router) {
        if (!authorizedRouters[router]) revert NotRouter(router);
        _;
    }

    modifier onlyAllowedVault(IERC4626 vault) {
        if (!authorizedVaults[vault]) revert NotVault(vault);
        _;
    }

    constructor(IPermit2 permit2) Ownable(_msgSender()) {
        PERMIT2 = permit2;
    }

    /**
     * @param token The IERC20 token to be claimed.
     */
    function withdrawToken(IERC20 token) external onlyOwner {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function withdrawNativeToken() external onlyOwner {
        payable(_msgSender()).sendValue(address(this).balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function approveTokenForRouter(
        IERC20 token,
        address router
    )
        public
        onlyOwner
        onlyAllowedRouter(router)
    {
        token.forceApprove(router, type(uint256).max);
        emit RouterApproved(router, token);
    }

    function toggleRouterAuthorization(address router) public onlyOwner {
        bool authorized = !authorizedRouters[router];
        authorizedRouters[router] = authorized;
        emit RouterAuthorized(router, authorized);
    }

    function toggleVaultAuthorization(IERC7540 vault) public onlyOwner {
        bool authorized = !authorizedVaults[vault];
        IERC20(vault.asset()).forceApprove(
            address(vault), authorized ? type(uint256).max : 0
        );
        authorizedVaults[vault] = authorized;
        emit VaultAuthorized(vault, authorized);
    }

    // internal function used only to execute the zap before request a deposit
    function _zapIn(
        IERC20 tokenIn,
        address router,
        uint256 amount,
        bytes calldata data
    )
        internal
    {
        uint256 expectedBalance; // of tokenIn (currently)

        if (msg.value == 0) {
            expectedBalance = tokenIn.balanceOf(address(this));
            _transferTokenInAndApprove(router, tokenIn, amount);
        } else {
            expectedBalance = address(this).balance - msg.value;
        }

        _executeZap(router, data); // zap

        uint256 balanceAfterZap = msg.value == 0
            ? tokenIn.balanceOf(address(this))
            : address(this).balance;

        if (balanceAfterZap > expectedBalance) {
            // Our balance is higher than expected, we shouldn't have received
            // any token
            revert InconsistantSwapData({
                expectedTokenInBalance: expectedBalance,
                actualTokenInBalance: balanceAfterZap
            });
        }
    }

    function _transferTokenInAndApprove(
        address router,
        IERC20 tokenIn,
        uint256 amount
    )
        internal
    {
        tokenIn.safeTransferFrom(_msgSender(), address(this), amount);
        if (tokenIn.allowance(_msgSender(), router) < amount) {
            tokenIn.forceApprove(router, amount);
        }
    }

    /*
     ########################
      USER RELATED FUNCTIONS
     ########################
    */
    // todo maybe remove minshares
    function zapAndDeposit(
        IERC20 tokenIn,
        IERC4626 vault,
        address router,
        uint256 amount,
        uint256 minShares,
        bytes calldata data
    )
        public
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
        returns (uint256)
    {
        if (minShares == 0) revert NullMinShares();

        uint256 initialTokenOutBalance =
            IERC20(vault.asset()).balanceOf(address(this)); // tokenOut balance to
            // deposit, not final value

        // Zap
        _zapIn(tokenIn, router, amount, data);

        // Deposit
        uint256 shares = vault.deposit(
            IERC20(vault.asset()).balanceOf(address(this))
                - initialTokenOutBalance,
            _msgSender()
        );

        if (shares < minShares) {
            revert NotEnoughSharesMinted({
                sharesMinted: shares,
                minSharesMinted: minShares
            });
        }

        emit ZapAndDeposit({
            vault: vault,
            router: router,
            tokenIn: tokenIn,
            amount: amount,
            shares: shares
        });

        return shares;
    }

    // todo check if swap is enough
    function zapAndRequestDeposit(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amountIn,
        bytes calldata data,
        bytes calldata swapData
    )
        public
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
    {
        uint256 initialTokenOutBalance =
            IERC20(vault.asset()).balanceOf(address(this)); // tokenOut balance to
            // deposit, not final value

        // Zap
        _zapIn(tokenIn, router, amountIn, swapData);

        // Request deposit
        vault.requestDeposit(
            IERC20(vault.asset()).balanceOf(address(this))
                - initialTokenOutBalance,
            _msgSender(),
            _msgSender(),
            data
        );

        emit ZapAndRequestDeposit({
            vault: vault,
            router: router,
            tokenIn: tokenIn,
            amount: amountIn
        });
    }

    /*
     ##########################
      PERMIT RELATED FUNCTIONS
     ##########################
    */

    function zapAndDepositWithPermit(
        IERC20 tokenIn,
        IERC4626 vault,
        address router,
        uint256 amount,
        uint256 minShares,
        bytes calldata swapData,
        PermitParams calldata permitParams
    )
        public
        returns (uint256)
    {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount) {
            _executePermit(tokenIn, _msgSender(), address(this), permitParams);
        }
        return
            zapAndDeposit(tokenIn, vault, router, amount, minShares, swapData);
    }

    function zapAndRequestDepositWithPermit(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amount,
        bytes calldata data,
        bytes calldata swapData,
        PermitParams calldata permitParams
    )
        public
    {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount) {
            _executePermit(tokenIn, _msgSender(), address(this), permitParams);
        }
        zapAndRequestDeposit(tokenIn, vault, router, amount, data, swapData);
    }

    function _executeZap(
        address target,
        bytes memory data
    )
        internal
        returns (bytes memory response)
    {
        (bool success, bytes memory _data) =
            target.call{ value: msg.value }(data);
        if (!success) {
            if (data.length > 0) revert SwapFailed(string(_data));
            else revert SwapFailed("Unknown reason");
        }
        return _data;
    }

    function _executePermit(
        IERC20 token,
        address owner,
        address spender,
        PermitParams calldata permitParams
    )
        internal
    {
        ERC20Permit(address(token)).permit(
            owner,
            spender,
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s
        );
    }

    /*
     ###########################
      PERMIT2 RELATED FUNCTIONS
     ###########################
    */

    // Deposit some amount of an ERC20 token into this contract
    // using Permit2.
    function execPermit2(Permit2Params calldata permit2Params) internal {
        // Transfer tokens from the caller to ourselves.
        PERMIT2.permitTransferFrom(
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

    function zapAndRequestDepositWithPermit2(
        IERC7540 vault,
        address router,
        uint256 amount,
        bytes calldata data,
        bytes calldata swapData,
        Permit2Params calldata permit2Params
    )
        external
    {
        if (
            IERC20(permit2Params.token).allowance(_msgSender(), address(this))
                < amount
        ) {
            execPermit2(permit2Params);
        }

        zapAndRequestDeposit(
            IERC20(permit2Params.token), vault, router, amount, data, swapData
        );
    }

    function zapAndDepositWithPermit2(
        IERC4626 vault,
        address router,
        uint256 amount,
        uint256 minShares,
        bytes calldata swapData,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (
            IERC20(permit2Params.token).allowance(_msgSender(), address(this))
                < amount
        ) {
            execPermit2(permit2Params);
        }

        return zapAndDeposit(
            IERC20(permit2Params.token),
            vault,
            router,
            amount,
            minShares,
            swapData
        );
    }
}
