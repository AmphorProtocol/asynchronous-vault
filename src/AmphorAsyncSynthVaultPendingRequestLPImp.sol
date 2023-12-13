//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC6909ib, ERC20} from "./utils/ERC6909ib.sol";
import {
    IERC20
} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Ownable
} from "@openzeppelin/contracts/access/Ownable.sol";
import {AmphorAsyncSynthVaultImp} from "./AmphorAsyncSynthVaultImp.sol";

contract AmphorAsyncSynthVaultPendingRequestLPImp is ERC6909ib, Ownable {

    using SafeERC20 for ERC20;

    ERC20 private immutable underyling; // usdc for deposits, shares for withdraws
    AmphorAsyncSynthVaultImp private immutable vault;

    constructor(
        ERC20 _underlying,
        string memory name,
        string memory symbol
    ) ERC6909ib(name, symbol) Ownable(_msgSender()) {
        underyling = _underlying;
        vault = AmphorAsyncSynthVaultImp(msg.sender);
    }

    function asset(uint256) public view virtual override returns (ERC20) {
        return underyling;
    }

    function totalAssets(uint256 tokenId) public view virtual override returns (uint256) {
        return underyling.balanceOf(address(this));
    }

    function decimals(uint256 tokenId) public view virtual override returns (uint8) {
        return underyling.decimals();
    }

    function deposit(uint256, uint256 assets, address receiver)
        public
        override
        returns (uint256 shares) 
    {
        super.deposit(vault.epochNonce(), assets, receiver);
    }

    function deposit(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        uint256 tokenId = vault.epochNonce();
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(tokenId, assets)) != 0, "ZERO_SHARES");
        ERC20 _asset = asset(tokenId);
        // Need to transfer before minting or ERC777s could reenter.
        _asset.safeTransferFrom(owner, address(this), assets);

        _mint(receiver, tokenId, shares);

        emit Deposit(tokenId, owner, receiver, assets, shares);

        afterDeposit(tokenId, assets, shares);
    }

    function mint(uint256, uint256 shares, address receiver)
        public
        override
        returns (uint256 assets) 
    {
        super.mint(vault.epochNonce(), shares, receiver);
    }

    function mint(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        uint256 tokenId = vault.epochNonce();

        assets = previewMint(tokenId, shares); // No need to check for rounding error, previewMint rounds up.

        ERC20 _asset = asset(tokenId);

        // Need to transfer before minting or ERC777s could reenter.
        _asset.safeTransferFrom(owner, address(this), assets);

        _mint(receiver, tokenId, shares);

        emit Deposit(tokenId, owner, receiver, assets, shares);

        afterDeposit(tokenId, assets, shares);
    }

    function withdraw(uint256, uint256 assets, address receiver, address owner)
        public
        override
        returns (uint256 shares) 
    {
        super.withdraw(vault.epochNonce(), assets, receiver, owner);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        returns (uint256 shares) 
    {
        super.withdraw(vault.epochNonce(), assets, receiver, owner);
    }

    function redeem(uint256, uint256 shares, address receiver, address owner)
        public
        override
        returns (uint256 assets) 
    {
        super.redeem(vault.epochNonce(), shares, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        returns (uint256 assets) 
    {
        super.redeem(vault.epochNonce(), shares, receiver, owner);
    }

    function burn(address account, uint256 tokenId, uint256 shares) external onlyOwner {
        if (balanceOf[account][tokenId] >= shares) _burn(account, tokenId, shares);
    }

    // Only for display purposes, nasty code
    function getPositiveBalances(address account)
        external
        view
        returns (uint256[] memory ids, uint256[] memory positiveBalances)
    {
        uint256 epochNonce = vault.epochNonce();
        uint256[] memory allBalances = new uint256[](epochNonce);
        uint256[] memory allIds = new uint256[](epochNonce);
        uint256 allBalancesIndex;
        for (allBalancesIndex; allBalancesIndex < epochNonce; allBalancesIndex++) {
            uint256 lpBalances = balanceOf[account][allBalancesIndex];
            if (lpBalances > 0) {
                allBalances[allBalancesIndex] = lpBalances;
                allIds[allBalancesIndex] = allBalancesIndex;
            }
        }
        positiveBalances = new uint256[](allBalancesIndex);
        ids = new uint256[](allBalancesIndex);
        uint256 positiveBalancesIndex;
        for (positiveBalancesIndex; positiveBalancesIndex < allBalancesIndex; positiveBalancesIndex++) {
            positiveBalances[positiveBalancesIndex] = positiveBalances[positiveBalancesIndex];
            ids[positiveBalancesIndex] = allIds[positiveBalancesIndex];
        }
    } 
}