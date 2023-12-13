//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC6909ib, ERC20} from "./utils/ERC6909ib.sol";
import {
    IERC20
} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {
    Ownable
} from "@openzeppelin/contracts/access/Ownable.sol";
import {AmphorAsyncSynthVaultImp} from "./AmphorAsyncSynthVaultImp.sol";

contract AmphorAsyncSynthVaultPendingRequestLPImp is ERC6909ib, Ownable {

    ERC20 private immutable underyling;
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

    function mint(uint256, uint256 shares, address receiver)
        public
        override
        returns (uint256 assets) 
    {
        super.mint(vault.epochNonce(), shares, receiver);
    }

    function withdraw(uint256, uint256 assets, address receiver, address owner)
        public
        override
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