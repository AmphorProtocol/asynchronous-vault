//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC7540, IERC165, IERC7540Redeem} from "./interfaces/IERC7540.sol";
import {
    Ownable,
    Ownable2Step
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    ERC20,
    IERC20,
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract AmphorAsyncSynthVaultImp is IERC7540, ERC20, ERC20Permit, Ownable2Step, Pausable {

    ERC20 public asset;

    constructor(
        ERC20 underlying,
        ERC20 oldShareToken,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(_msgSender()) {
        asset = underlying;
    }

    function nextEpoch(uint256 returnedUnderlyingAmount) external returns (uint256) {
    }

    function requestDeposit(uint256 assets, address operator) external {}
    function pendingDepositRequest(address operator) external view returns (uint256 assets) {return 0;}
    function requestRedeem(uint256 shares, address operator, address owner) external {}
    function pendingRedeemRequest(address operator) external view returns (uint256 shares) {return 0;}
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId
            || interfaceId == type(IERC4626).interfaceId;
    }
    function totalAssets() external view returns (uint256 totalManagedAssets) {return 0;}
    function convertToShares(uint256 assets) external view returns (uint256 shares) {return 0;}
    function convertToAssets(uint256 shares) external view returns (uint256 assets) {return 0;}
    function maxDeposit(address receiver) external view returns (uint256 maxAssets) {return 0;}
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {return 0;}
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {return 0;}
    function maxMint(address receiver) external view returns (uint256 maxShares) {return 0;}
    function previewMint(uint256 shares) external view returns (uint256 assets) {return 0;}
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {return 0;}
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {return 0;}
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {return 0;}
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {return 0;}
    function maxRedeem(address owner) external view returns (uint256 maxShares) {return 0;}
    function previewRedeem(uint256 shares) external view returns (uint256 assets) {return 0;}
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {return 0;}
}