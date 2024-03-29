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
import { PermitParams, AsyncVault } from "./AsyncVault.sol";
import { ERC20Permit } from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

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

    /**
     * @notice The `authorizedVaults` mapping is used to check if a vault is
     * authorized to interact with the `VaultZapper` contract.
     */
    mapping(IERC4626 vault => bool isAuthorized) public authorizedVaults;

    /**
     * @notice The `authorizedRouters` mapping is used to check if a router is
     * authorized to interact with the `VaultZapper` contract.
     */
    mapping(address routerAddress => bool isAuthorized) public authorizedRouters;

    /**
     * @dev The `ZapAndDeposit` event is emitted when a user zaps in and
     * deposits
     * assets into a vault.
     */
    event ZapAndRequestDeposit(
        IERC7540 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount
    );

    /**
     * @dev The `ZapAndDeposit` event is emitted when a user zaps in and
     * deposits
     * assets into a vault.
     */
    event ZapAndDeposit(
        IERC4626 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount,
        uint256 shares
    );

    /**
     * @dev The `RouterApproved` event is emitted when a router is approved to
     * interact with a token.
     */
    event RouterApproved(address indexed router, IERC20 indexed token);
    /**
     * @dev The `RouterAuthorized` event is emitted when a router is authorized
     * to interact with the `VaultZapper` contract.
     */
    event RouterAuthorized(address indexed router, bool allowed);
    /**
     * @dev The `VaultAuthorized` event is emitted when a vault is authorized to
     * interact with the `VaultZapper` contract.
     */
    event VaultAuthorized(IERC4626 indexed vault, bool allowed);

    /**
     * @dev The `NotRouter` error is emitted when a router is not authorized to
     * interact with the `VaultZapper` contract.
     */
    error NotRouter(address router);
    /**
     * @dev The `NotVault` error is emitted when a vault is not authorized to
     * interact with the `VaultZapper` contract.
     */
    error NotVault(IERC4626 vault);
    /**
     * @dev The `SwapFailed` error is emitted when a swap fails.
     */
    error SwapFailed(string reason);
    /**
     * @dev The `InconsistantSwapData` error is emitted when the swap data is
     * inconsistant.
     */
    error InconsistantSwapData(
        uint256 expectedTokenInBalance, uint256 actualTokenInBalance
    );
    /**
     * @dev The `NotEnoughSharesMinted` error is emitted when the amount of
     * shares
     * minted is not enough.
     */
    error NotEnoughSharesMinted(uint256 sharesMinted, uint256 minSharesMinted);
    /**
     * @dev The `NotEnoughUnderlying` error is emitted when the amount of
     * underlying assets is not enough.
     */
    error NotEnoughUnderlying(
        uint256 previewedUnderlying, uint256 withdrawedUnderlying
    );

    /**
     * @dev The `NullMinShares` error is emitted when the minimum amount of
     * shares
     * to mint is null.
     */
    error NullMinShares();

    /**
     * @dev See
     * https://dedaub.com/blog/phantom-functions-and-the-billion-dollar-no-op
     */
    error PermitFailed();

    /**
     * @dev The `onlyAllowedRouter` modifier is used to check if a router is
     * authorized to interact with the `VaultZapper` contract.
     */
    modifier onlyAllowedRouter(address router) {
        if (!authorizedRouters[router]) revert NotRouter(router);
        _;
    }

    /**
     * @dev The `onlyAllowedVault` modifier is used to check if a vault is
     * authorized to interact with the `VaultZapper` contract.
     */
    modifier onlyAllowedVault(IERC4626 vault) {
        if (!authorizedVaults[vault]) revert NotVault(vault);
        _;
    }

    constructor() Ownable(_msgSender()) { }

    /**
     * @dev The `withdrawToken` function is used to withdraw tokens from the
     * `VaultZapper` contract.
     */
    function withdrawToken(IERC20 token) external onlyOwner {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    /**
     * @dev The `withdrawNativeToken` function is used to withdraw native tokens
     * from the `VaultZapper` contract.
     */
    function withdrawNativeToken() external onlyOwner {
        payable(_msgSender()).sendValue(address(this).balance);
    }

    /**
     * @dev The `pause` function is used to pause the `VaultZapper` contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev The `unpause` function is used to unpause the `VaultZapper`
     * contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev The `approveTokenForRouter` function is used to approve a token for
     * a
     * router.
     */
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

    /**
     * @dev The `toggleRouterAuthorization` function is used to toggle the
     * authorization of a router.
     */
    function toggleRouterAuthorization(address router) public onlyOwner {
        bool authorized = !authorizedRouters[router];
        authorizedRouters[router] = authorized;
        emit RouterAuthorized(router, authorized);
    }

    /**
     * @dev The `toggleVaultAuthorization` function is used to toggle the
     * authorization of a vault.
     */
    function toggleVaultAuthorization(IERC7540 vault) public onlyOwner {
        bool authorized = !authorizedVaults[vault];
        IERC20(vault.asset()).forceApprove(
            address(vault), authorized ? type(uint256).max : 0
        );
        authorizedVaults[vault] = authorized;
        emit VaultAuthorized(vault, authorized);
    }

    /**
     * @dev The `_zapIn` function is used to zap in assets into a vault.
     */
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

    /**
     * @dev The `_transferTokenInAndApprove` function is used to transfer tokens
     * into the `VaultZapper` contract and approve them for a router.
     */
    function _transferTokenInAndApprove(
        address router,
        IERC20 tokenIn,
        uint256 amount
    )
        internal
    {
        tokenIn.safeTransferFrom(_msgSender(), address(this), amount);
        if (tokenIn.allowance(address(this), router) < amount) {
            tokenIn.forceApprove(router, amount);
        }
    }

    /*
     ########################
      USER RELATED FUNCTIONS
     ########################
    */

    /**
     * @dev The `zapAndDeposit` function is used to zap in and deposit assets
     * into a vault.
     */
    function zapAndDeposit(
        IERC20 tokenIn,
        IERC4626 vault,
        address router,
        uint256 amount,
        bytes calldata data
    )
        public
        payable
        onlyAllowedRouter(router)
        onlyAllowedVault(vault)
        whenNotPaused
        returns (uint256)
    {
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

        emit ZapAndDeposit({
            vault: vault,
            router: router,
            tokenIn: tokenIn,
            amount: amount,
            shares: shares
        });

        return shares;
    }

    /**
     * @dev The `zapAndRequestDeposit` function is used to zap in and request a
     * deposit of assets into a vault.
     */
    function zapAndRequestDeposit(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amountIn,
        bytes calldata swapData,
        bytes calldata callback7540Data
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
            address(this),
            callback7540Data
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

    /**
     * @dev The `zapAndDepositWithPermit` function is used to zap in and deposit
     * assets into a vault with a permit.
     */
    function zapAndDepositWithPermit(
        IERC20 tokenIn,
        IERC4626 vault,
        address router,
        uint256 amount,
        bytes calldata swapData,
        PermitParams calldata permitParams
    )
        public
        returns (uint256)
    {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount) {
            _execPermit(tokenIn, _msgSender(), address(this), permitParams);
        }
        return zapAndDeposit(tokenIn, vault, router, amount, swapData);
    }

    /**
     * @dev The `zapAndRequestDepositWithPermit` function is used to zap in and
     * request a deposit of assets into a vault with a permit.
     */
    function zapAndRequestDepositWithPermit(
        IERC20 tokenIn,
        IERC7540 vault,
        address router,
        uint256 amount,
        bytes calldata swapData,
        PermitParams calldata permitParams,
        bytes calldata callback7540Data
    )
        public
    {
        if (tokenIn.allowance(_msgSender(), address(this)) < amount) {
            _execPermit(tokenIn, _msgSender(), address(this), permitParams);
        }
        zapAndRequestDeposit(
            tokenIn, vault, router, amount, swapData, callback7540Data
        );
    }

    /**
     * @dev The `_executeZap` function is used to execute a zap.
     */
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

    /**
     * @dev The `_executePermit` function is used to execute a permit.
     */
    function _execPermit(
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
        if (token.allowance(owner, spender) != permitParams.value) {
            revert PermitFailed();
        }
    }
}
