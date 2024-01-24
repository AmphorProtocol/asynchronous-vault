// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20Permit, ERC20} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract PermitERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {
        _mint(msg.sender, 10000 * 10 ** 6);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
