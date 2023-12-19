//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// check before the engage new requests or implement batched version of deposits/redeem claims
// TODO: imp an approveFrom for the pendingLP
// TODO: imp upgradability

import {IERC7540, IERC165, IERC7540Redeem} from "./interfaces/IERC7540.sol";
import {
    Ownable,
    Ownable2Step
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    IERC20,
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Pausable,
    Pausable,
    ERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AsyncVaultPendingLPImp, SafeERC20} from "./AsyncVaultPendingLPImp.sol";

contract AmphorAsyncSynthVaultImp is IERC7540, ERC20Pausable, Ownable2Step, ERC20Permit {

    /*
     ######
      LIBS
     ######
    */

    /**
     * @dev The `Math` lib is only used for `mulDiv` operations.
     */
    using Math for uint256;

    /**
     * @dev The `SafeERC20` lib is only used for `safeTransfer` and
     * `safeTransferFrom` operations.
     */
    using SafeERC20 for IERC20;

    /*
     ########
      EVENTS
     ########
    */

    /**
     * @dev Emitted when an epoch starts.
     * @param timestamp The block timestamp of the epoch start.
     * @param lastSavedBalance The `lastSavedBalance` when the vault start.
     * @param totalShares The total amount of shares when the vault start.
     */
    event EpochStart(
        uint256 indexed timestamp, uint256 lastSavedBalance, uint256 totalShares
    );

    /**
     * @dev Emitted when an epoch ends.
     * @param timestamp The block timestamp of the epoch end.
     * @param lastSavedBalance The `lastSavedBalance` when the vault end.
     * @param returnedAssets The total amount of underlying assets returned to
     * the vault before collecting fees.
     * @param fees The amount of fees collected.
     * @param totalShares The total amount of shares when the vault end.
     */
    event EpochEnd(
        uint256 indexed timestamp,
        uint256 lastSavedBalance,
        uint256 returnedAssets,
        uint256 fees,
        uint256 totalShares
    );

    /**
     * @dev Emitted when fees are changed.
     * @param oldFees The old fees.
     * @param newFees The new fees.
     */
    event FeesChanged(uint16 oldFees, uint16 newFees);

    /*
     ########
      ERRORS
     ########
    */

    /**
     * @dev The rules doesn't allow the perf fees to be higher than 30.00%.
     */
    error FeesTooHigh();

    /**
     * @dev Attempted to deposit more underlying assets than the max amount for
     * `receiver`.
     */
    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );

    /**
     * @dev Attempted to redeem more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);


    /*
     #####################################
      AMPHOR SYNTHETIC RELATED ATTRIBUTES
     #####################################
    */

    /**
     * @dev The perf fees applied on the positive yield.
     * @return Amount of the perf fees applied on the positive yield.
     */
    uint16 public feesInBps;

    IERC20 public immutable _asset;
    uint256 public epochNonce = 1; // in order to start at epoch 1, otherwise users might try to claim epoch -1 requests
    uint256[] public bigAssets; // pending withdrawals requests that has been processed && waiting for claim/deposit
    uint256[] public bigShares; // pending deposits requests that has been processed && waiting for claim/withdraw
    uint256 public totalAssets; // total working assets (in the strategy), not including pending withdrawals money

    AsyncVaultPendingLPImp public depositRequestLP;
    AsyncVaultPendingLPImp public withdrawRequestLP;


    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol,
        string memory depositRequestLPName,
        string memory depositRequestLPSymbol,
        string memory withdrawRequestLPName,
        string memory withdrawRequestLPSymbol
    ) ERC20(name, symbol) Ownable(_msgSender()) ERC20Permit(name) {
        _asset = IERC20(underlying);
        depositRequestLP = new AsyncVaultPendingLPImp(underlying, depositRequestLPName, depositRequestLPSymbol);
        withdrawRequestLP = new AsyncVaultPendingLPImp(underlying, withdrawRequestLPName, withdrawRequestLPSymbol);
    }

    function requestDeposit(uint256 assets, address receiver, address owner) public whenNotPaused {
        // Claim not claimed request
        uint256 lastRequestId = depositRequestLP.lastRequestId(owner);
        uint256 lastRequestBalance = depositRequestLP.balanceOf(owner, lastRequestId);
        if (lastRequestBalance > 0 && lastRequestId != epochNonce) // We don't want to call _deposit for nothing and we don't want to cancel a current request if the user just want to increase it.
            _deposit(owner, receiver, lastRequestId, lastRequestBalance);

        // Create a new request
        depositRequestLP.deposit(epochNonce, assets, receiver, owner);
        depositRequestLP.setLastRequest(owner, epochNonce);

        //TODO emit event ?
    }
    function withdrawDepositRequest(uint256 assets, address receiver, address owner) external whenNotPaused {
        depositRequestLP.withdraw(epochNonce, assets, receiver, owner);
        //TODO emit event ?
    }
    function pendingDepositRequest(address owner) external view returns (uint256 assets) {
        return depositRequestLP.balanceOf(owner, epochNonce);
    }
    function requestRedeem(uint256 shares, address receiver, address owner, bytes memory) external whenNotPaused {
        // Claim not claimed request
        uint256 lastRequestId = depositRequestLP.lastRequestId(owner);
        uint256 lastRequestBalance = depositRequestLP.balanceOf(owner, lastRequestId);
        if (lastRequestBalance > 0 && lastRequestId != epochNonce) // We don't want to call _redeem for nothing and we don't want to cancel a current request if the user just want to increase it.
            _redeem(owner, receiver, lastRequestId, lastRequestBalance);

        withdrawRequestLP.deposit(epochNonce, shares, receiver, owner);
        //TODO emit event ?
    }
    function withdrawRedeemRequest(uint256 shares, address receiver, address owner) external whenNotPaused {
        withdrawRequestLP.withdraw(epochNonce, shares, receiver, owner);
        //TODO emit event ?
    }
    function pendingRedeemRequest(address owner) external view returns (uint256 shares) {
        return withdrawRequestLP.balanceOf(owner, epochNonce);
    }
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    /*
     ####################################
      GENERAL ERC-4626 RELATED FUNCTIONS
     ####################################
    */

    /*
     * @dev The `asset` function is used to return the address of the underlying
     * @return address of the underlying asset.
     */
    function asset() public view returns (address) {
        return address(_asset);
    }

    /**
     * @dev See {IERC4626-convertToShares}.
     * @notice The `convertToShares` function is used to calculate shares amount
     * received in exchange of the specified underlying assets amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @dev See {IERC4626-convertToAssets}.
     * @notice The `convertToAssets` function is used to calculate underlying
     * assets amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of assets received in exchange of the specified shares
     * amount.
     */
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function maxDeposit(address owner) public view returns (uint256) {
        return depositRequestLP.balanceOf(owner, epochNonce - 1);
    }

    // TODO: implement this correclty if possible
    function maxMint(address) public pure returns (uint256) {
        return 0;
    }

    // TODO: implement this correclty if possible
    function maxWithdraw(address) public pure returns (uint256) {
        return 0; // check if the rounding is correct
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return withdrawRequestLP.balanceOf(owner, epochNonce - 1);
    }

    /**
     * @dev The `previewDeposit` function is used to calculate shares amount
     * received in exchange of the specified underlying amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertDepositLPToShares(epochNonce - 1, assets, Math.Rounding.Floor);
    }

    function previewDeposit(uint256 epochId, uint256 assets) public view returns (uint256) {
        return _convertDepositLPToShares(epochId, assets, Math.Rounding.Floor);
    }

    // TODO implement this correctly if possible
    function previewMint(uint256) public pure returns (uint256) {
        return 0;
    }

    //TODO implement this correctly if possible
    function previewWithdraw(uint256) public pure returns (uint256) {
        return 0;
    }

    /**
     * @dev The `previewRedeem` function is used to calculate the underlying
     * assets amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertWithdrawLPToAssets(epochNonce - 1, shares, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver)
        public
        whenNotPaused
        returns (uint256)
    {
        return _deposit(_msgSender(), receiver, epochNonce - 1, assets);
    }

    // assets = pending lp balance
    // shares = shares to mint
    function _deposit(address owner, address receiver, uint256 requestId, uint256 assets)
        internal
        returns (uint256)
    {
        uint256 maxAssets = maxDeposit(owner); // what he can claim from the last epoch request 
        if (assets > maxAssets) { // he is trying to claim more than he can by saying he has more pending lp that he has in reality
            revert ERC4626ExceededMaxDeposit(owner, assets, maxAssets);
        }

        uint256 sharesAmount = previewDeposit(requestId, assets);
        depositRequestLP.burn(owner, requestId, assets);
        // _mint(receiver, sharesAmount); // actually the shares have already been minted into the nextEpoch function
        IERC20(address(this)).safeTransfer(receiver, sharesAmount); // transfer the vault shares to the receiver
        bigShares[requestId] += sharesAmount; // decrease the bigShares

        emit Deposit(owner, receiver, assets, sharesAmount);

        return sharesAmount;
    }

    // TODO: implement this correclty if possible
    function mint(uint256, address) public pure returns (uint256) {
        return 0;
    }

    // TODO: implement this correclty if possible
    function withdraw(uint256, address, address)
        external
        pure
        returns (uint256)
    {
        return 0;
    }

    /**
     * @dev The `redeem` function is used to redeem the specified amount of
     * shares in exchange of the corresponding underlying assets amount from
     * owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function redeem(uint256 shares, address receiver, address owner)
        external
        whenNotPaused
        returns (uint256)
    {
        return _redeem(owner, receiver, epochNonce - 1, shares);
    }
    
    function _redeem(address owner, address receiver, uint256 requestId, uint256 shares)
        internal
        returns (uint256)
    {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);

        uint256 assetsAmount = previewRedeem(shares);
        withdrawRequestLP.burn(owner, requestId, shares);

        _asset.safeTransfer(receiver, assetsAmount);
        bigAssets[requestId] -= assetsAmount; // decrease the bigAssets

        emit Withdraw(_msgSender(), receiver, owner, assetsAmount, shares);

        return assetsAmount;
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support
     * for rounding direction.
     * @param assets Theunderlying assets amount to be converted into shares.
     * @param rounding The rounding direction.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(
            totalSupply() + 1, totalAssets + 1, rounding
        );
    }

    function _convertDepositLPToShares(uint256 epochId, uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(
            bigShares[epochId] + 1, depositRequestLP.totalSupply(epochId) + 1, rounding
        );
    }

    function _convertWithdrawLPToAssets(uint256 epochId, uint256 pendingLPs, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return pendingLPs.mulDiv(
            bigAssets[epochId] + 1, withdrawRequestLP.totalSupply(epochId) + 1, rounding
        );
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support
     * for rounding direction.
     * @param shares The shares amount to be converted into underlying assets.
     * @param rounding The rounding direction.
     * @return Amount of underlying assets received in exchange of the
     * specified amount of shares.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return shares.mulDiv(
            totalAssets + 1, totalSupply() + 1, rounding
        );
    }

    /*
     ####################################
      AMPHOR SYNTHETIC RELATED FUNCTIONS
     ####################################
    */

    // TODO: implement this
    function nextEpoch(uint256 returnedUnderlyingAmount) public onlyOwner returns (uint256) {
        // (end + start epochs)

        // TODO
        // 1. take fees from returnedUnderlyingAmount
        // 7. we update the totalAssets
        // 2. with the resting amount we know how much cost a share
        // 3. we can take the pending deposits underlying (same as this vault underlying) and mint shares
        // 4. we update the bigShares array for the appropriate epoch (epoch 0 request is a deposit into epoch 1...)
        // 5. we can take the pending withdraws shares and redeem underlying (which are shares of this vault) against this vault underlying
        // 6. we update the bigAssets array for the appropriate epoch (epoch 0 request is a withdraw at the end of the epoch 0...)

        ///////////////////////
        // Ending current epoch
        ///////////////////////
        uint256 fees;

        if (returnedUnderlyingAmount > totalAssets && feesInBps > 0) {
            uint256 profits;
            unchecked {
                profits = returnedUnderlyingAmount - totalAssets;
            }
            fees = (profits).mulDiv(feesInBps, 10000, Math.Rounding.Ceil);
        }

        totalAssets = returnedUnderlyingAmount - fees;

        // Can be done in one time at the end
        SafeERC20.safeTransferFrom(
            _asset, _msgSender(), address(this), returnedUnderlyingAmount - fees
        );

        emit EpochEnd(
            block.timestamp,
            totalAssets,
            returnedUnderlyingAmount,
            fees,
            totalSupply()
        );

        ///////////////////
        // Pending deposits
        ///////////////////
        uint256 pendingDeposit = depositRequestLP.nextEpoch(epochNonce); // get the underlying of the pending deposits
        // Updating the bigShares array
        bigShares.push(pendingDeposit.mulDiv(
            totalSupply() + 1, totalAssets + 1, Math.Rounding.Floor
        ));
        // Minting the shares
        _mint(address(this), bigShares[epochNonce]); // mint the shares into the vault
        // Update the totalAssets
        totalAssets += pendingDeposit;

        /////////////////
        // Pending redeem
        /////////////////
        uint256 pendingRedeem = withdrawRequestLP.nextEpoch(epochNonce); // get the shares of the pending withdraws
        // Updating the bigAssets array
        bigAssets.push(pendingRedeem.mulDiv(
            totalAssets + 1, totalSupply() + 1, Math.Rounding.Floor
        ));
        // Burn the vault shares
        _burn(address(this), pendingRedeem); // burn the shares from the vault
        // Update the totalAssets
        totalAssets -= bigAssets[epochNonce];

        //////////////////
        // Start new epoch
        //////////////////
        _asset.safeTransfer(owner(), totalAssets);

        emit EpochStart(block.timestamp, totalAssets, totalSupply());

        return ++epochNonce;
    }

    /**
     * @dev The `setFees` function is used to modify the protocol fees.
     * @notice The `setFees` function is used to modify the perf fees.
     * It can only be called by the owner of the contract (`onlyOwner` modifier).
     * It can't exceed 30% (3000 in BPS).
     * @param newFees The new perf fees to be applied.
     */
    function setFees(uint16 newFees) external onlyOwner {
        if (newFees > 3000) revert FeesTooHigh();
        feesInBps = newFees;
        emit FeesChanged(feesInBps, newFees);
    }

    // TODO: implement this correclty
    /**
     * @dev The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * @notice The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier).
     * @param token The IERC20 token to be claimed.
     */
    function claimToken(IERC20 token) external onlyOwner {
        if (token == _asset) {/*TODO: get the discrepancy between returned assets and pending deposits*/}
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    // Pausability
    function pause() public onlyOwner {
        _pause();
        // depositRequestLP.pause();
        // withdrawRequestLP.pause();
    }

    function unpause() public onlyOwner {
        _unpause();
        // depositRequestLP.unpause();
        // withdrawRequestLP.unpause();
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) whenNotPaused {
        super._update(from, to, value);
    }
}