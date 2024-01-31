//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Test } from "forge-std/Test.sol";

abstract contract Assertions is Test {
    function isInGrossProfit(
        IERC4626 vault,
        address owner,
        uint256 deposited
    )
        public
        view
        returns (bool)
    {
        return vault.convertToAssets(vault.balanceOf(owner)) >= deposited
            ? true
            : false;
    }

    function assertSharesBalance(
        IERC4626 vault,
        address owner,
        uint256 expected
    )
        public
    {
        assertEq(
            vault.balanceOf(owner),
            expected,
            "shares balance != expected balance"
        );
    }

    
}
