//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Test } from "forge-std/Test.sol";

abstract contract Assertions is Test {
    function assertIsInProfit(
        IERC4626 vault,
        address owner,
        uint256 deposited
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation =
            " | Current (left) < Deposited value (right)";
        assertGt(
            vault.convertToAssets(vault.balanceOf(owner)),
            deposited,
            string.concat(userLabel, " is in loss in ", vaultLabel, explanation)
        );
    }

    function assertIsInLoss(
        IERC4626 vault,
        address owner,
        uint256 deposited
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation =
            " | Current (left) > Deposited value (right)";
        assertLt(
            vault.convertToAssets(vault.balanceOf(owner)),
            deposited,
            string.concat(
                userLabel, " is in profit in ", vaultLabel, explanation
            )
        );
    }

    function assertSharesBalance(
        IERC4626 vault,
        address owner,
        uint256 expected
    )
        public
    {
        string memory userLabel = vm.getLabel(owner);
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.balanceOf(owner),
            expected,
            string.concat(
                userLabel,
                " has wrong shares balance in ",
                vaultLabel,
                explanation
            )
        );
    }

    function assertTotalSupply(IERC4626 vault, uint256 expected) public {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.totalSupply(),
            expected,
            string.concat("Total shares supply in ", vaultLabel, explanation)
        );
    }

    function assertTotalAssets(IERC4626 vault, uint256 expected) public {
        string memory vaultLabel = vm.getLabel(address(vault));
        string memory explanation = " | Current (left) != Expected (right)";
        assertEq(
            vault.totalAssets(),
            expected,
            string.concat("Total assets in ", vaultLabel, explanation)
        );
    }
}
