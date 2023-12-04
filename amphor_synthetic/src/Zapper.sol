//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable, Ownable2Step} from
    "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PermitParams} from "./AmphorSyntheticVaultPermitImp.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract VaultZapper is Ownable2Step, Pausable {
    /**
     * @dev The `SafeERC20` lib is only used for `safeTransfer`,
     * `safeTransferFrom` and `forceApprove` operations.
     */
    using SafeERC20 for IERC20;

    mapping(IERC4626 => bool) public authorizedVaults;
    mapping(address => bool) public authorizedRouters;

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

    event ZapAndDeposit(
        IERC4626 indexed vault,
        address indexed router,
        IERC20 tokenIn,
        uint256 amount,
        uint256 shares
    );

    event RedeemAndZap(
        IERC4626 indexed vault, address indexed router, uint256 shares
    );

    event WithdrawAndZap(
        IERC4626 indexed vault, address indexed router, uint256 shares
    );

    event routerApproved(address indexed router, IERC20 indexed token);
    event routerAuthorized(address indexed router, bool allowed);
    event vaultAuthorized(IERC4626 indexed vault, bool allowed);
    event vaultApproved(IERC4626 indexed vault, address indexed asset);

    modifier onlyAllowedRouter(address router) {
        if (!authorizedRouters[router]) revert NotRouter(router);
        _;
    }

    modifier onlyAllowedVault(IERC4626 vault) {
        if (!authorizedVaults[vault]) revert NotVault(vault);
        _;
    }

    constructor() Ownable(_msgSender()) {}

    /**
     * @dev The `withdrawToken` function is used to claim other tokens that have
     * been sent to the vault.
     * @notice The `withdrawToken` function is used to claim other tokens that have
     * been sent to the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier).
     * @param token The IERC20 token to be claimed.
     */
    function withdrawToken(IERC20 token) external onlyOwner {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function withdrawNativeToken() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
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
    {
        token.forceApprove(address(router), type(uint256).max);
        emit routerApproved(address(router), token);
    }

    function toggleRouterAuthorization(address router) public onlyOwner {
        bool authorized = !authorizedRouters[router];
        authorizedRouters[router] = authorized;
        emit routerAuthorized(router, authorized);
    }

    function toggleVaultAuthorization(IERC4626 vault) public onlyOwner {
        bool authorized = !authorizedVaults[vault];
        if (authorized) _approveVault(IERC4626(vault));
        else IERC20(vault.asset()).forceApprove(address(vault), 0);
        authorizedVaults[vault] = authorized;
        emit vaultAuthorized(vault, authorized);
    }

    function _approveVault(IERC4626 vault) internal {
        IERC20(vault.asset()).forceApprove(address(vault), type(uint256).max);
        emit vaultApproved(vault, vault.asset());
    }

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

        uint256 expectedBalance;

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

        uint256 shares = _depositInVault(vault);
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

    function _transferTokenInAndApprove(
        address router,
        IERC20 tokenIn,
        uint256 amount
    ) private {
        tokenIn.safeTransferFrom(_msgSender(), address(this), amount);
        if (tokenIn.allowance(_msgSender(), address(router)) < amount) {
            tokenIn.forceApprove(address(router), amount);
        }
    }

    function _depositInVault(IERC4626 vault) private returns (uint256) {
        address asset = vault.asset();

        uint256 amount = IERC20(asset).balanceOf(address(this));

        return vault.deposit(amount, msg.sender);
    }

    function redeemAndZap(
        IERC4626 vault,
        address router,
        uint256 shares, // shares to redeem
        bytes calldata data
    ) public onlyAllowedRouter(router) onlyAllowedVault(vault) whenNotPaused {
        // zapper balance in term of vault underlying
        uint256 balanceBeforeRedeem =
            IERC20(vault.asset()).balanceOf(address(this));
        IERC4626(vault).redeem(shares, address(this), _msgSender());

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
        emit RedeemAndZap(vault, router, shares);
    }

    function withdrawAndZap(
        IERC4626 vault,
        address router,
        uint256 assets, // assets amount to withdraw
        bytes calldata data
    ) public onlyAllowedRouter(router) onlyAllowedVault(vault) whenNotPaused {
        uint256 balanceBeforeWithdraw =
            IERC20(vault.asset()).balanceOf(address(this));
        vault.withdraw(assets, address(this), _msgSender());

        // Once the assets are out of the vault, we can zap them into the desired asset
        _execute(router, data);

        uint256 balanceAfterSwap =
            IERC20(vault.asset()).balanceOf(address(this));

        if (balanceAfterSwap > balanceBeforeWithdraw) {
            revert InconsistantSwapData({
                expectedTokenInBalance: balanceBeforeWithdraw,
                actualTokenInBalance: balanceAfterSwap
            });
        }
        emit WithdrawAndZap(vault, router, assets);
    }

    function zapAndDepositWithPermit(
        IERC20 tokenIn,
        IERC4626 vault,
        address router,
        uint256 amount,
        uint256 minShares,
        bytes calldata data,
        PermitParams calldata permitParams
    ) public payable returns (uint256) {
        _executePermit(tokenIn, _msgSender(), address(this), permitParams);
        return zapAndDeposit(tokenIn, vault, router, amount, minShares, data);
    }

    function redeemAndZapWithPermit(
        IERC4626 vault,
        address router,
        uint256 shares, // shares to redeem
        bytes calldata data,
        PermitParams calldata permitParams
    ) public {
        _executePermit(IERC20(vault), _msgSender(), address(this), permitParams);
        redeemAndZap(vault, router, shares, data);
    }

    function withdrawAndZapWithPermit(
        IERC4626 vault,
        address router,
        uint256 assets, // assets amount to withdraw
        bytes calldata data,
        PermitParams calldata permitParams
    ) public {
        _executePermit(IERC20(vault), _msgSender(), address(this), permitParams);
        withdrawAndZap(vault, router, assets, data);
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
}
