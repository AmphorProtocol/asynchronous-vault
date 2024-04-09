// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

interface ERC7540Receiver {
    function onERC7540DepositReceived(
        address operator,
        address owner,
        uint256 requestId,
        uint256 assets,
        bytes memory data
    )
        external
        returns (bytes4);

    function onERC7540RedeemReceived(
        address operator,
        address owner,
        uint256 requestId,
        uint256 shares,
        bytes memory data
    )
        external
        returns (bytes4);
}
