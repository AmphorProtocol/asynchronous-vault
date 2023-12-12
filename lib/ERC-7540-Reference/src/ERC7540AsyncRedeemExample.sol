// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "solmate/mixins/ERC4626.sol";

// THIS VAULT IS AN UNOPTIMIZED, POTENTIALLY UNSECURE REFERENCE EXAMPLE AND IN NO WAY MEANT TO BE USED IN PRODUCTION


/** 
@notice ERC7540 Implementing Delayed Async Withdrawals 

    This Vault has the following properties:
    - yield for the underlying asset is assumed to be transferred directly into the vault by some arbitrary mechanism
    - async redemptions are subject to a 3 day delay
    - new redemptions restart the 3 day delay even if the prior redemption is claimable. 
        This can be resolved by using a more sophisticated algorithm for storing multiple requests.
    - the redemption exchange rate is locked in immediately upon request.
    - users can only redeem the maximum amount. 
        To allow partial claims, the redeem and withdraw functions would need to allow for pro rata claims. 
        Conversions between claimable assets/shares should be checked for rounding safety.
*/
contract ERC7540AsyncRedeemExample is ERC4626 {

    mapping(address => RedemptionRequest) internal _pendingRedemption;
    uint256 internal _totalPendingAssets;

    struct RedemptionRequest {
        uint256 assets;
        uint256 shares;
        uint32 claimableTimestamp;
    }

    uint32 public constant REDEEM_DELAY_SECONDS = 3 days;

event RedeemRequest(address indexed sender, address indexed operator, address indexed owner, uint256 shares);

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {}

    function totalAssets() public view override returns (uint256) {
        // total assets pending redemption must be removed from the reported total assets
        // otherwise pending assets would be treated as yield for outstanding shares
        return asset.balanceOf(address(this)) - _totalPendingAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC7540 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice this redemption request locks in the current exchange rate, restarts the withdrawal timelock delay, and increments any outstanding request
    /// NOTE: if there is an outstanding claimable request, users benefit from claiming before requesting again
    function requestRedeem(uint256 shares, address operator, address owner) public {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        uint256 assets;
        require((assets = convertToAssets(shares)) != 0, "ZERO_ASSETS");

        _burn(owner, shares);


        uint256 currentPendingShares = _pendingRedemption[operator].shares;
        uint256 currentPendingAssets = _pendingRedemption[operator].assets;
        _pendingRedemption[operator] = RedemptionRequest(assets + currentPendingAssets, shares + currentPendingShares, uint32(block.timestamp) + REDEEM_DELAY_SECONDS);

        _totalPendingAssets += assets;
        
        emit RedeemRequest(msg.sender, operator, owner, shares);
    }

    function pendingRedeemRequest(address operator) public view returns (uint256 shares) {
        RedemptionRequest memory request = _pendingRedemption[operator];

        // If the claimable timestamp is in the future, return the pending shares
        // Otherwise return 0 as all are claimable
        if (request.claimableTimestamp > block.timestamp) {
            return request.shares;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 OVERRIDDEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdraw(
        uint256 assets,
        address receiver,
        address operator
    ) public override returns (uint256 shares) {
        require(msg.sender == operator, "Sender must be operator");
        // The maxWithdraw call checks that assets are claimable
        require(assets != 0 && assets == maxWithdraw(operator), "Must claim nonzero maximum");

        shares = _pendingRedemption[operator].shares;
        delete _pendingRedemption[operator];

        _totalPendingAssets -= assets;

        asset.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, operator, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address operator
    ) public override returns (uint256 assets) {
        require(msg.sender == operator, "Sender must be operator");
        // The maxWithdraw call checks that assets are claimable
        require(shares != 0 && shares == maxRedeem(operator), "Must claim nonzero maximum");

        assets = _pendingRedemption[operator].assets;
        delete _pendingRedemption[operator];

        _totalPendingAssets -= assets;

        asset.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, operator, assets, shares);
    }

    // The max functions return the outstanding quanitity if if the redeem delay window has passed

    function maxWithdraw(address operator) public view override returns (uint256) {
        RedemptionRequest memory request = _pendingRedemption[operator];

        // If the redeem delay window has passed, return the pending assets
        if (request.claimableTimestamp <= block.timestamp) {
            return request.assets;
        }
    }

    function maxRedeem(address operator) public view override returns (uint256) {
        RedemptionRequest memory request = _pendingRedemption[operator];

        // If the redeem delay window has passed, return the pending shares
        if (request.claimableTimestamp <= block.timestamp) {
            return request.shares;
        }
    }

    // Preview functions always revert for async flows

    function previewWithdraw(uint256) public pure override returns (uint256) {
        revert ();
    }

    function previewRedeem(uint256) public pure override returns (uint256) {
        revert ();
    }

}
