//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC6909} from "ERC-6909/ERC6909.sol";
import {
    Ownable,
    Ownable2Step
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract AmphorAsyncSynthVaultRequestLPImp is ERC6909, Ownable2Step {

    /// @notice Total supply for a token.
    mapping(uint256 tokenId => uint256 supply) public totalSupply;
    constructor() ERC6909() Ownable(_msgSender()) {}

    function mint(
        address operator,
        uint256 requestId,
        uint256 amount
    ) external onlyOwner {
        _mint(operator, requestId, amount);
    }

    function burn(
        address operator,
        uint256 requestId,
        uint256 amount
    ) external onlyOwner {
        _burn(operator, requestId, amount);
    }

    function _mint(address receiver, uint256 id, uint256 amount) internal {
        // WARNING: important safety checks should precede calls to this method.
        balanceOf[receiver][id] += amount;
        unchecked {
            totalSupply[id] += amount;
        }
        emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal {
        // WARNING: important safety checks should precede calls to this method.
        unchecked {
            totalSupply[id] -= amount;
        }

        balanceOf[sender][id] -= amount;
        emit Transfer(msg.sender, sender, address(0), id, amount);
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