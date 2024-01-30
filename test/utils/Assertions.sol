//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

abstract contract Assertions {
    function isInGrossProfit(IERC4626 vault, address owner, uint256 deposited) public view returns (bool) {
        return vault.convertToAssets(vault.balanceOf(owner)) >= deposited ? true : false;
    }

    
}
