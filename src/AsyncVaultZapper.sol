//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable2Step, Ownable} from
    "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC7540} from "./interfaces/IERC7540.sol";
import {PermitParams} from "./SynthVaultPermit.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IPermit2, ISignatureTransfer} from "permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}

contract AsyncVaultZapper is Ownable2Step, Pausable {
    /**
     * @dev The `SafeERC20` lib is only used for `safeTransfer`,
     * `safeTransferFrom` and `forceApprove` operations.
     */
    using SafeERC20 for IERC20;

    /**
     * @dev The `Address` lib is only used for `sendValue` operations.
     */
    using Address for address payable;

    mapping(IERC7540 => bool) public authorizedVaults;
    mapping(address => bool) public authorizedRouters;

    // The canonical permit2 contract.
    IPermit2 public immutable permit2;

    error NotRouter(address router);
    error NotVault(IERC7540 vault);
    error SwapFailed(string reason);
    error InconsistantSwapData(
        uint256 expectedTokenInBalance, uint256 actualTokenInBalance
    );
    error NotEnoughSharesMinted(uint256 sharesMinted, uint256 minSharesMinted);
    error NotEnoughUnderlying(
        uint256 previewedUnderlying, uint256 withdrawedUnderlying
    );
    error NullMinShares();

    event ZapAndRequestDeposit(
        IERC7540 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount
    );

    event ClaimRedeemAndZap(
        IERC7540 indexed vault, address indexed router, uint256 shares, uint256 assets
    );

    event routerApproved(address indexed router, IERC20 indexed token);
    event routerAuthorized(address indexed router, bool allowed);
    event vaultAuthorized(IERC7540 indexed vault, bool allowed);

    modifier onlyAllowedRouter(address router) {
        if (!authorizedRouters[router]) revert NotRouter(router);
        _;
    }

    modifier onlyAllowedVault(IERC7540 vault) {
        if (!authorizedVaults[vault]) revert NotVault(vault);
        _;
    }

    constructor(IPermit2 _permit2) Ownable(_msgSender()) {
        permit2 = _permit2;
    }

    /**
     * @dev The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * @notice The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier).
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

    function approveTokenForRouter(IERC20 token, address router)
        public
        onlyOwner
        onlyAllowedRouter(router)
    {
        token.forceApprove(router, type(uint256).max);
        emit routerApproved(router, token);
    }

    function toggleRouterAuthorization(address router) public onlyOwner {
        bool authorized = !authorizedRouters[router];
        authorizedRouters[router] = authorized;
        emit routerAuthorized(router, authorized);
    }

    function toggleVaultAuthorization(IERC7540 vault) public onlyOwner {
        bool authorized = !authorizedVaults[vault];
        IERC20(vault.asset()).forceApprove(
            address(vault), authorized ? type(uint256).max : 0
        );
        authorizedVaults[vault] = authorized;
        emit vaultAuthorized(vault, authorized);
    }

    // internal function used only to execute the zap before request a deposit
    function _zapIn(
        IERC20 tokenIn,
        address router,
        uint256 amount,
        bytes calldata data
    ) internal {
        uint256 expectedBalance; // of tokenIn (currently)

        if (msg.value == 0) {
            expectedBalance = tokenIn.balanceOf(address(this));
            _transferTokenInAndApprove(router, tokenIn, amount);
        } else {
            expectedBalance = address(this).balance - msg.value;
        }

        _execute(router, data); // zap

        uint256 balanceAfterZap = msg.value == 0
            ? tokenIn.balanceOf(address(this))
            : address(this).balance;

        if (balanceAfterZap > expectedBalance) {
            // Our balance is higher than expected, we shouldn't have received any token
            revert InconsistantSwapData({
                expectedTokenInBalance: expectedBalance,
                actualTokenInBalance: balanceAfterZap
            });
        }
    }

    function zapAndRequestDeposit(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amount,
        bytes calldata data
    )
        public
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
        // returns (uint256) // request receipt tokens amount minted
    {
        uint256 initialTokenOutBalance =
            IERC20(vault.asset()).balanceOf(address(this)); // tokenOut balance to deposit, not final value

        // Zap
        _zapIn(tokenIn, router, amount, data);

        // Request deposit
        vault.requestDeposit(
            IERC20(vault.asset()).balanceOf(address(this))
                - initialTokenOutBalance,
            _msgSender(),
            _msgSender()
        );

        emit ZapAndRequestDeposit({
            vault: vault,
            router: router,
            tokenIn: tokenIn,
            amount: amount
        });
    }

    function _transferTokenInAndApprove(
        address router,
        IERC20 tokenIn,
        uint256 amount
    ) private {
        tokenIn.safeTransferFrom(_msgSender(), address(this), amount);
        if (tokenIn.allowance(_msgSender(), router) < amount) {
            tokenIn.forceApprove(router, amount);
        }
    }

    function claimRedeemAndZap(
        IERC7540 vault,
        address router,
        uint256 shares, // redeemable shares to claim
        bytes calldata data
    ) public onlyAllowedRouter(router) onlyAllowedVault(vault) whenNotPaused returns (uint256) {
        // zapper balance in term of vault underlying
        uint256 balanceBeforeRedeem =
            IERC20(vault.asset()).balanceOf(address(this));

        // Claim redeem
        uint256 assets = IERC7540(vault).redeem(shares, address(this), _msgSender());

        // Once the assets are out of the vault, we can zap them into the desired asset
        _execute(router, data);

        uint256 balanceAfterSwap =
            IERC20(vault.asset()).balanceOf(address(this));

        if (balanceAfterSwap > balanceBeforeRedeem) {
            revert InconsistantSwapData({
                expectedTokenInBalance: balanceBeforeRedeem,
                actualTokenInBalance: balanceAfterSwap
            });
        }

        emit ClaimRedeemAndZap(vault, router, shares, assets);

        return assets;
    }

    function zapAndRequestDepositWithPermit(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amount,
        bytes calldata data,
        PermitParams calldata permitParams
    ) public payable /*returns (uint256)*/ {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount) {
            _executePermit(tokenIn, _msgSender(), address(this), permitParams);
        }
        /*return*/ zapAndRequestDeposit(tokenIn, vault, router, amount, data);
    }

    function redeemAndZapWithPermit(
        IERC7540 vault,
        address router,
        uint256 shares, // shares to redeem
        bytes calldata data,
        PermitParams calldata permitParams
    ) public {
        if (IERC20(vault).allowance(_msgSender(), address(this)) < shares) {
            _executePermit(
                IERC20(vault), _msgSender(), address(this), permitParams
            );
        }
        claimRedeemAndZap(vault, router, shares, data);
    }

    function _execute(address target, bytes memory data)
        private
        returns (bytes memory response)
    {
        (bool success, bytes memory _data) = target.call{value: msg.value}(data);
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
    ) private {
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

    function zapAndRequestDepositWithPermit2(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amount,
        bytes calldata data,
        Permit2Params calldata permit2Params
    ) external {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount)
            execPermit2(permit2Params);

        /*return*/ zapAndRequestDeposit(tokenIn, vault, router, amount, data);
    }
}
