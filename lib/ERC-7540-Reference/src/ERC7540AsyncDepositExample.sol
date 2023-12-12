// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "solmate/mixins/ERC4626.sol";
import "solmate/auth/Owned.sol";

// THIS VAULT IS AN UNOPTIMIZED, POTENTIALLY UNSECURE REFERENCE EXAMPLE AND IN NO WAY MEANT TO BE USED IN PRODUCTION

/**
 * @notice ERC7540 Implementing Controlled Async Deposits
 *
 *     This Vault has the following properties:
 *     - yield for the underlying asset is assumed to be transferred directly into the vault by some arbitrary mechanism
 *     - async deposits are subject to approval by an owner account
 *     - users can only deposit the maximum amount.
 *         To allow partial claims, the deposit and mint functions would need to allow for pro rata claims.
 *         Conversions between claimable assets/shares should be checked for rounding safety.
 */
contract ERC7540AsyncDepositExample is ERC4626, Owned {
    using SafeTransferLib for ERC20;

    mapping(address => PendingDeposit) internal _pendingDeposit;
    mapping(address => ClaimableDeposit) internal _claimableDeposit;
    uint256 internal _totalPendingAssets;

    struct PendingDeposit {
        uint256 assets;
    }

    struct ClaimableDeposit {
        uint256 assets;
        uint256 shares;
    }

    event DepositRequest(address indexed sender, address indexed operator, uint256 assets);

    constructor(ERC20 _asset, string memory _name, string memory _symbol)
        ERC4626(_asset, _name, _symbol)
        Owned(msg.sender)
    {}

    function totalAssets() public view override returns (uint256) {
        // total assets pending redemption must be removed from the reported total assets
        // otherwise pending assets would be treated as yield for outstanding shares
        return asset.balanceOf(address(this)) - _totalPendingAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC7540 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice this deposit request is added to any pending deposit request
    function requestDeposit(uint256 assets, address operator) public {
        require(assets != 0, "ZERO_ASSETS");

        asset.safeTransferFrom(msg.sender, address(this), assets);

        uint256 currentPendingAssets = _pendingDeposit[operator].assets;
        _pendingDeposit[operator] = PendingDeposit(assets + currentPendingAssets);

        _totalPendingAssets += assets;

        emit DepositRequest(msg.sender, operator, assets);
    }

    function pendingDepositRequest(address operator) public view returns (uint256 assets) {
        assets = _pendingDeposit[operator].assets;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FULFILLMENT LOGIC
    //////////////////////////////////////////////////////////////*/
    function fulfillDeposit(address operator) public onlyOwner returns (uint256 shares) {
        PendingDeposit memory request = _pendingDeposit[operator];

        require(request.assets != 0, "ZERO_ASSETS");

        shares = convertToShares(request.assets);
        _mint(address(this), shares);

        uint256 currentClaimableAssets = _claimableDeposit[operator].assets;
        uint256 currentClaimableShares = _claimableDeposit[operator].shares;
        _claimableDeposit[operator] =
            ClaimableDeposit(request.assets + currentClaimableAssets, shares + currentClaimableShares);

        delete _pendingDeposit[operator];
        _totalPendingAssets -= request.assets;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 OVERRIDDEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        // The maxWithdraw call checks that assets are claimable
        require(assets != 0 && assets == maxDeposit(msg.sender), "Must claim nonzero maximum");

        shares = _claimableDeposit[msg.sender].shares;
        delete _claimableDeposit[msg.sender];

        transfer(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        // The maxWithdraw call checks that shares are claimable
        require(shares != 0 && shares == maxMint(msg.sender), "Must claim nonzero maximum");

        assets = _claimableDeposit[msg.sender].assets;
        delete _claimableDeposit[msg.sender];

        transfer(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxDeposit(address operator) public view override returns (uint256) {
        ClaimableDeposit memory claimable = _claimableDeposit[operator];
        return claimable.assets;
    }

    function maxMint(address operator) public view override returns (uint256) {
        ClaimableDeposit memory claimable = _claimableDeposit[operator];
        return claimable.shares;
    }

    // Preview functions always revert for async flows

    function previewDeposit(uint256) public pure override returns (uint256) {
        revert();
    }

    function previewMint(uint256) public pure override returns (uint256) {
        revert();
    }
}
