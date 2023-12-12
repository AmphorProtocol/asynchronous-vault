//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC6909} from "ERC-6909/ERC6909.sol";
import {
    Ownable,
    Ownable2Step
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract AmphorAsyncSynthVaultRequestLPImp is ERC6909, Ownable2Step {
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
      emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal {
      // WARNING: important safety checks should precede calls to this method.
      balanceOf[sender][id] -= amount;
      emit Transfer(msg.sender, sender, address(0), id, amount);
    }

    // TODO: add batched version
}