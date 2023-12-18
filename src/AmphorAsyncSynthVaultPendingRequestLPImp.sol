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

contract AmphorAsyncSynthVaultPendingRequestLPImp is ERC6909ib, Ownable {

    using SafeERC20 for ERC20;

    ERC20 private immutable underyling; // usdc for deposits, shares for withdraws
    mapping(address => uint256) public lastRequestId;

    constructor(
        ERC20 _underlying,
        string memory name,
        string memory symbol
    ) ERC6909ib(name, symbol) Ownable(_msgSender()) {
        underyling = _underlying;
    }

    function asset(uint256) public view virtual override returns (ERC20) {
        return underyling;
    }

    function totalAssets(uint256) public view virtual override returns (uint256) {
        return underyling.balanceOf(address(this)); // This contract holds the underlying asset of only one epoch
    }

    function decimals(uint256) public view virtual override returns (uint8) {
        return underyling.decimals();
    }

    function deposit(uint256 epochNonce, uint256 assets, address receiver)
        public
        override
        onlyOwner
        returns (uint256) 
    {
        return super.deposit(epochNonce, assets, receiver);
    }

    function deposit(uint256 epochNonce, uint256 assets, address receiver, address owner)
        public
        onlyOwner
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(epochNonce, assets)) != 0, "ZERO_SHARES");
        ERC20 _asset = asset(epochNonce);
        // Need to transfer before minting or ERC777s could reenter.
        _asset.safeTransferFrom(owner, address(this), assets);

        _mint(receiver, epochNonce, shares);

        emit Deposit(epochNonce, owner, receiver, assets, shares);

        afterDeposit(epochNonce, assets, shares);
    }

    function mint(uint256 epochNonce, uint256 shares, address receiver)
        public
        onlyOwner
        override
        returns (uint256) 
    {
        return super.mint(epochNonce, shares, receiver);
    }

    function withdraw(uint256 epochNonce, uint256 assets, address receiver, address owner)
        public
        onlyOwner
        override
        returns (uint256) 
    {
        return super.withdraw(epochNonce, assets, receiver, owner);
    }

    function redeem(uint256 epochNonce, uint256 shares, address receiver, address owner)
        public
        onlyOwner
        override
        returns (uint256) 
    {
        return super.redeem(epochNonce, shares, receiver, owner);
    }

    function burn(address account, uint256 tokenId, uint256 shares) external onlyOwner {
        if (balanceOf[account][tokenId] >= shares) _burn(account, tokenId, shares);
    }

    function setLastRequest(address owner, uint256 id) external onlyOwner {
        lastRequestId[owner] = id;
    }

    function nextEpoch(uint256 currentEpochNonce) external onlyOwner returns (uint256 returnedUnderlying) {
        returnedUnderlying = totalAssets(currentEpochNonce);
        underyling.safeTransfer(owner(), returnedUnderlying);
    }
}