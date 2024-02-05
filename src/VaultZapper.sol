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
import { PermitParams } from "./SynthVaultPermit.sol";
import { ERC20Permit } from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import {
    IPermit2, ISignatureTransfer
} from "permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    ISignatureTransfer.PermitBatchTransferFrom permit;
    ISignatureTransfer.SignatureTransferDetails[] transferDetails;
    bytes signature;
}

// struct Permit2Params {
    // uint256 amount;
    // address token;
    // InputTokenInfo[] inputs;
    // Permit2Info permit2Infos;
// }

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
        IERC7540 indexed vault,
        address indexed router,
        uint256 shares,
        uint256 assets
    );
    event ZapAndDeposit(
        IERC4626 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount,
        uint256 shares
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

    // Storage
    IPermit2 canonicalPermit2;

    constructor(IPermit2 _canonicalPermit2) Ownable(_msgSender()) {
        canonicalPermit2 = _canonicalPermit2;
    }

    /**
     * @dev The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * @notice The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * It can only be called by the owner of the contract (`onlyOwner`
     * modifier).
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

        _execute(router, data); // zap

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

    // zap native
    function _zapNativeAndRequestDeposit(
        IERC7540 vault,
        uint256 amountIn,
        address router,
        bytes calldata data,
        bytes calldata swapData
    )
        internal
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
    {
        // Native eth balance
        uint256 nativeBalanceBefore = address(this).balance;

        // Zap
        _zapIn(IERC20(0x0), router, msg.value, swapData);

        // Request deposit
        vault.requestDeposit(
            IERC20(vault.asset()).balanceOf(address(this)),
            _msgSender(),
            _msgSender(),
            data
        );

        emit ZapAndRequestDeposit({
            vault: vault,
            router: router,
            tokenIn: IERC20(0x0),
            amount: msg.value
        });

        // Check if the zap was successful
        uint256 nativeBalanceAfter = address(this).balance;

        if (nativeBalanceAfter > nativeBalanceBefore) {
            revert InconsistantSwapData({
                expectedTokenInBalance: nativeBalanceBefore,
                actualTokenInBalance: nativeBalanceAfter
            });
        }
    }

    function _zapNativeAndDeposit(
        IERC4626 vault,
        uint256 amountIn,
        address router,
        bytes calldata data,
        bytes calldata swapData
    )
        internal
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
    {
        // Native eth balance
        uint256 nativeBalanceBefore = address(this).balance;

        // Zap
        _zapIn(IERC20(0x0), router, msg.value, swapData);

        // Request deposit
        vault.deposit(
            vault.asset()).balanceOf(address(this),
            _msgSender()
        );

        emit ZapAndDeposit({
            vault: vault,
            router: router,
            tokenIn: IERC20(0x0),
            amount: msg.value
        });

        // Check if the zap was successful
        uint256 nativeBalanceAfter = address(this).balance;

        if (nativeBalanceAfter > nativeBalanceBefore) {
            revert InconsistantSwapData({
                expectedTokenInBalance: nativeBalanceBefore,
                actualTokenInBalance: nativeBalanceAfter
            });
        }
    }

    ///////////////

    // non native zap and deposit

    function zapAndRequestDeposit(
        IERC7540 vault,
        address router,
        IERC20[] tokensIn,
        uint256[] amountsIn,
        uint256[] minShares,
        bytes[] calldata swapData
    )
        public
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
    // returns (uint256) // request receipt tokens amount minted
    {
        if (msg.value > 0) {
            _zapNativeAndRequestDeposit(
                vault,
                0,
                router,
                new bytes(0),
                new bytes(0)
            );
        }

        uint256 initialTokenOutBalance =
            IERC20(vault.asset()).balanceOf(address(this)); // tokenOut balance to
            // deposit, not final value

        // Zap (loop here)
        // _zapIn(tokenIn, router, amount, swapData);

        // Request deposit
        // vault.requestDeposit(
        //     IERC20(vault.asset()).balanceOf(address(this))
        //         - initialTokenOutBalance,
        //     _msgSender(),
        //     _msgSender(),
        //     data
        // );

        // emit ZapAndRequestDeposit({
        //     vault: vault,
        //     router: router,
        //     tokenIn: tokenIn,
        //     amount: amount
        // });
    }

    function _transferTokenInAndApprove(
        address router,
        IERC20 tokenIn,
        uint256 amount
    )
        private
    {
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
    )
        public
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
        returns (uint256)
    {
        // zapper balance in term of vault underlying
        uint256 balanceBeforeRedeem =
            IERC20(vault.asset()).balanceOf(address(this));

        // Claim redeem
        uint256 assets =
            IERC7540(vault).redeem(shares, address(this), _msgSender());

        // Once the assets are out of the vault, we can zap them into the
        // desired asset
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
        bytes calldata swapData,
        PermitParams calldata permitParams
    )
        public
        payable /*returns (uint256)*/
    {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount) {
            _executePermit(tokenIn, _msgSender(), address(this), permitParams);
        }
        /*return*/
        zapAndRequestDeposit(tokenIn, vault, router, amount, data, swapData);
    }

    function redeemAndZapWithPermit(
        IERC7540 vault,
        address router,
        uint256 shares, // shares to redeem
        bytes calldata data,
        PermitParams calldata permitParams
    )
        public
    {
        if (IERC20(vault).allowance(_msgSender(), address(this)) < shares) {
            _executePermit(
                IERC20(vault), _msgSender(), address(this), permitParams
            );
        }
        claimRedeemAndZap(vault, router, shares, data);
    }

    function _execute(
        address target,
        bytes memory data
    )
        private
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
        private
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

    // Works for single and batch permit2
    function execPermit2(Permit2Params calldata permit2Params) internal {
        // Transfer tokens from the caller to ourselves.
        canonicalPermit2.permitTransferFrom(
            permit2Params.permit,
            permit2Params.transferDetails,
            _msgSender(),
            permit2Params.signature
        );
    }

    function zapAndRequestDepositWithPermit2(
        IERC7540 vault,
        address router,
        Permit2Params calldata permit2Params,
        bytes calldata data,
        bytes calldata swapData
    )
        external
        payable
    {
        if (msg.value > 0) {
            zapAndRequestDeposit {value: msg.value} (
                vault,
                router,
                IERC20(0x0),
                0,
                data,
                swapData
            );
        }
        execPermit2(permit2Params);
        for (uint256 i = 0; i < permit2Params.transferDetails.length; i++) {
            zapAndRequestDeposit(
                permit2Params.permit.permitted.token,
                vault,
                router,
                permit2Params.permit.permitted.amount,
                data,
                swapData
            );
        }
        
    }
}
