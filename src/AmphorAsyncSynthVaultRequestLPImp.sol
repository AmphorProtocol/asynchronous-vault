//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC6909ib, ERC20} from "./utils/ERC6909ib.sol";
import {
    IERC20
} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {
    Ownable
} from "@openzeppelin/contracts/access/Ownable.sol";

contract AmphorAsyncSynthVaultRequestLPImp is ERC6909ib, Ownable {

    ERC20 private immutable underyling;
    uint256 public constant MAX_UINT256 = type(uint256).max;
    uint256[] private _totalAssets;

    constructor(ERC20 _underlying, string memory name, string memory symbol) ERC6909ib(name, symbol) Ownable(_msgSender()) {
        underyling = _underlying;
    }

    function asset(uint256) public view virtual override returns (ERC20) {
        return ERC20(underyling);
    }
    
    function totalAssets(uint256 tokenId) public view virtual override returns (uint256) {
        return _totalAssets[tokenId];
    }

    function decimals(uint256 tokenId) public view virtual override returns (uint8) {
        return underyling.decimals();
    }

    function getPositiveBalances(address account, uint256 epochNonce)
        external
        view
        returns (uint256[] memory ids, uint256[] memory positiveBalances)
    {
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