//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC7540, IERC165, IERC7540Redeem} from "./interfaces/IERC7540.sol";
import {ERC7540Receiver} from "./interfaces/ERC7540Receiver.sol";
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
import {SafeERC20} from "./SynthVaultRequestReceipt.sol";
import {
    IPermit2, ISignatureTransfer
} from "permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}

struct Epoch {
    uint256 totalSupplySnapshot;
    uint256 totalAssetsSnapshot;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

// TODO
// Add functions like totalPendingDeposits() and totalPendingRedeems() for all requests
// Add functions like totalClaimableDeposits() and totalClaimableRedeems() for all requests
// Add functions like convertToShares(uint256 asset, uint256 requestId) and convertToAssets(uint256 shares, uint256 requestId) for all requests
// Eventually add functions like maxDepositRequest(address owner) and maxRedeemRequest(address owner) for all requests
// Add functions like previewClaimDeposit(uint256 asset, uint256 requestId) and previewClaimRedeem(uint256 shares, uint256 requestId) for all requests

contract SynthVault is IERC7540, ERC20Pausable, Ownable2Step, ERC20Permit {
    /**
     * #######
     *   LIBS
     *  ######
     */
    uint256 constant BPS_DIVIDER = 10000;

    // @dev The `Math` lib is only used for `mulDiv` operations.
    using Math for uint256;

    // @dev The `SafeERC20` lib is only used for `safeTransfer` and
    // `safeTransferFrom` operations.
    using SafeERC20 for IERC20;

    /**
     * ########
     *   EVENTS
     *  ########
     */

    event EpochStart(
        uint256 indexed timestamp, uint256 lastSavedBalance, uint256 totalShares
    );

    event EpochEnd(
        uint256 indexed timestamp,
        uint256 lastSavedBalance,
        uint256 returnedAssets,
        uint256 fees,
        uint256 totalShares
    );

    event FeesChanged(uint16 oldFees, uint16 newFees);

    event AsyncDeposit(
        uint256 indexed requestId,
        uint256 requestedAssets,
        uint256 acceptedAssets
    );

    event AsyncRedeem(
        uint256 indexed requestId,
        uint256 requestedShares,
        uint256 acceptedShares
    );

    event WithdrawDepositRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedAssets,
        uint256 newRequestedAssets
    );

    event WithdrawRedeemRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedShares,
        uint256 newRequestedShares
    );

    event ClaimDeposit(
        uint256 indexed requestId,
        address indexed caller,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    event ClaimRedeem(
        uint256 indexed requestId,
        address indexed caller,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /**
     * ########
     *   ERRORS
     *  ########
     */

    // @dev The vault is in locked state. Emitted if the tx cannot happen in
    // this state.
    error VaultIsLocked();

    // @dev The vault is open and the tx cannot happen in this state.
    error VaultIsOpen();

    // @dev The rules doesn't allow the perf fees to be higher than 30.00%.
    error FeesTooHigh();

    // @dev Claiming the underlying assets is not allowed.
    error CannotClaimAsset();

    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    // @dev Attempted to mint less shares than the min amount for `receiver`.
    // This error is only thrown when the `depositMinShares` function is used.
    // @notice The `depositMinShares` function is used to deposit underlying
    // assets into the vault. It also checks that the amount of shares minted is
    // greater or equal to the specified minimum amount.
    // @param owner The address of the owner.
    // @param shares The shares amount to be converted into underlying assets.
    // @param minShares The minimum amount of shares to be minted.
    error ERC4626NotEnoughSharesMinted(
        address owner, uint256 shares, uint256 minShares
    );

    // @dev Attempted to withdraw more underlying assets than the max amount for
    // `receiver`.
    // This error is only thrown when the `mintMaxAssets` function is used.
    // @notice The `mintMaxAssets` function is used to mint the specified amount
    // of shares in exchange of the corresponding underlying assets amount from
    // owner. It also checks that the amount of assets deposited is less or
    // equal to the specified maximum amount.
    // @param owner The address of the owner.
    // @param assets The underlying assets amount to be converted into shares.
    // @param maxAssets The maximum amount of assets to be deposited.
    error ERC4626TooMuchAssetsDeposited(
        address owner, uint256 assets, uint256 maxAssets
    );

    error VaultIsEmpty(); // We cannot start an epoch with an empty vault
    error ClaimableRequestPending();
    error MustClaimFirst();

    modifier whenClosed() {
        if (isOpen()) revert VaultIsOpen();
        _;
    }

    /**
     * ####################################
     *   GENERAL PERMIT2 RELATED ATTRIBUTES
     *  ####################################
     */
    // The canonical permit2 contract.
    IPermit2 public immutable permit2;

    /**
     * #####################################
     *   AMPHOR SYNTHETIC RELATED ATTRIBUTES
     *  #####################################
     */

    // @dev The perf fees applied on the positive yield.
    // @return Amount of the perf fees applied on the positive yield.

    uint16 public feesInBps;

    IERC20 internal immutable _asset;
    uint256 public epochNonce = 1; // in order to start at epoch 1, otherwise users might try to claim epoch -1 requests
    uint256 internal _lastSavedBalance;
    uint256 public totalAssets;
    uint256 internal totalPendingDepositRequest;
    uint256 internal totalPendingRedeemRequest;

    bool public _isOpen;

    mapping(uint256 => Epoch) internal epoch;
    mapping(address => uint256) lastDepositRequestId; // user => epochNonce
    mapping(address => uint256) lastRedeemRequestId; // user => epochNonce

    /**
     * ############################
     *   AMPHOR SYNTHETIC FUNCTIONS
     * ############################
     */

    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol,
        IPermit2 _permit2
    ) ERC20(name, symbol) Ownable(_msgSender()) ERC20Permit(name) {
        _asset = IERC20(underlying);
        permit2 = _permit2;
    }

    function isCurrentEpoch(uint256 requestId) internal view returns (bool) {
        return requestId == epochNonce;
    }

    function requestDeposit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    ) public whenClosed whenNotPaused {
        // Check if the user has a claimable request
        uint256 lastRequestId = lastDepositRequestId[receiver];
        uint256 lastRequestBalance =
            epoch[lastRequestId].depositRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochNonce;

        if (hasClaimableRequest) revert MustClaimFirst();

        // Create a new request
        _createDepositRequest(assets, receiver, owner, data);
    }

    function _createDepositRequest(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    ) internal {
        _asset.safeTransferFrom(owner, address(this), assets);
        totalPendingDepositRequest += assets;
        epoch[epochNonce].depositRequestBalance[receiver] += assets;

        if (lastDepositRequestId[receiver] != epochNonce) {
            lastDepositRequestId[receiver] = epochNonce;
        }

        if (data.length > 0) {
            require(
                ERC7540Receiver(receiver).onERC7540DepositReceived(
                    _msgSender(), owner, epochNonce, data
                ) == ERC7540Receiver.onERC7540DepositReceived.selector,
                "receiver failed"
            );
        }

        emit DepositRequest(receiver, owner, epochNonce, _msgSender(), assets);
    }

    function totalPendingDeposits() public view returns (uint256) {
        return totalPendingDepositRequest; // todo renam
    }

    function totalPendingRedeems() public view returns (uint256) {
        return totalPendingRedeemRequest;
    }

    function maxDepositRequest(address) public view returns (uint256) {
        return !isOpen() || paused() ? 0 : type(uint256).max;
    }

    function maxRedeemRequest(address owner) public view returns (uint256) {
        return !isOpen() || paused() ? 0 : balanceOf(owner);
    }

    function claimAndRequestDeposit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    ) external {
        claimDeposit(receiver);
        requestDeposit(assets, receiver, owner, data);
    }

    function claimAndRequestRedeem(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    ) external {
        claimRedeem(receiver);
        requestRedeem(shares, receiver, owner, data);
    }

    function withdrawDepositRequest(
        uint256 assets,
        address receiver,
        address owner
    ) external whenNotPaused {
        uint256 oldBalance = epoch[epochNonce].depositRequestBalance[owner];
        epoch[epochNonce].depositRequestBalance[owner] -= assets;
        totalPendingDepositRequest -= assets;
        _asset.safeTransfer(receiver, assets);

        emit WithdrawDepositRequest(
            epochNonce,
            owner,
            oldBalance,
            epoch[epochNonce].depositRequestBalance[owner]
        );
    }

    function pendingDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        return epoch[lastDepositRequestId[owner]].depositRequestBalance[owner];
    }

    function claimableDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];
        return isCurrentEpoch(lastRequestId) ? 0
            : epoch[lastRequestId].depositRequestBalance[owner];
    }

    function requestRedeem(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    ) public whenClosed whenNotPaused {
        // Check if the user has a claimable request
        uint256 lastRequestId = lastRedeemRequestId[receiver];
        uint256 lastRequestBalance =
            epoch[lastRequestId].redeemRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochNonce;

        if (hasClaimableRequest) revert MustClaimFirst();

        // Create a new request
        _createRedeemRequest(shares, receiver, owner, data);
    }

    function _createRedeemRequest(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    ) internal {
        transferFrom(owner, address(this), shares);
        totalPendingRedeemRequest += shares;
        epoch[epochNonce].redeemRequestBalance[receiver] += shares;
        lastRedeemRequestId[owner] = epochNonce;

        if (data.length > 0) {
            require(
                ERC7540Receiver(receiver).onERC7540RedeemReceived(
                    _msgSender(), owner, epochNonce, data
                ) == ERC7540Receiver.onERC7540RedeemReceived.selector,
                "receiver failed"
            );
        }

        emit DepositRequest(receiver, owner, epochNonce, _msgSender(), shares);
    }

    function withdrawRedeemRequest(
        uint256 shares,
        address receiver,
        address owner
    ) external whenNotPaused {
        uint256 oldBalance = epoch[epochNonce].redeemRequestBalance[owner];
        epoch[epochNonce].redeemRequestBalance[owner] -= shares;
        totalPendingRedeemRequest -= shares;
        transfer(receiver, shares);

        emit WithdrawRedeemRequest(
            epochNonce,
            owner,
            oldBalance,
            epoch[epochNonce].redeemRequestBalance[owner]
        );
        // TODO: emit an event
    }

    function pendingRedeemRequest(address owner)
        external
        view
        returns (uint256)
    {
        return epoch[epochNonce].redeemRequestBalance[owner];
    }

    function claimableRedeemRequest(address owner)
        external
        view
        returns (uint256)
    {
        uint256 lastRequestId = lastRedeemRequestId[owner];
        return isCurrentEpoch(lastRequestId) ? 0 // todo : potential opti
            : epoch[lastRequestId].redeemRequestBalance[owner];
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    function previewClaimDeposit(address owner)
        public
        view
        returns (uint256)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 assets = epoch[lastRequestId].depositRequestBalance[owner];
        return _convertToShares(assets, lastRequestId, Math.Rounding.Floor);
    }

    function previewClaimRedeem(address owner)
        public
        view
        returns (uint256)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 shares = epoch[lastRequestId].redeemRequestBalance[owner];
        return _convertToAssets(shares, lastRequestId, Math.Rounding.Floor);
    }

    function claimDeposit(address receiver)
        public
        returns (uint256 shares)
    {
        address owner = _msgSender();
        uint256 lastRequestId = lastDepositRequestId[owner];

        shares = previewClaimDeposit(owner);

        uint256 assets = epoch[lastRequestId].depositRequestBalance[owner];
        epoch[lastRequestId].depositRequestBalance[owner] = 0;

        transfer(receiver, shares);

        emit ClaimDeposit(lastRequestId, _msgSender(), receiver, assets, shares);
    }

    function claimRedeem(address receiver)
        public
        returns (uint256 assets)
    {
        address owner = _msgSender();
        uint256 lastRequestId = lastDepositRequestId[owner];

        assets = previewClaimRedeem(owner);

        uint256 shares = epoch[lastRequestId].redeemRequestBalance[owner];
        epoch[lastRequestId].redeemRequestBalance[owner] = 0;

        _asset.safeTransfer(receiver, assets);

        emit ClaimRedeem(lastRequestId, owner, receiver, assets, shares);
    }

    /**
     * ####################################
     *   GENERAL ERC-4626 RELATED FUNCTIONS
     *  ####################################
     */

    // @dev The `asset` function is used to return the address of the underlying
    // @return address of the underlying asset.
    function asset() public view returns (address) {
        return address(_asset);
    }

    // @dev See {IERC4626-convertToShares}.
    // @notice The `convertToShares` function is used to calculate shares amount
    // received in exchange of the specified underlying assets amount.
    // @param assets The underlying assets amount to be converted into shares.
    // @return Amount of shares received in exchange of the specified underlying
    // assets amount.
    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, epochNonce, Math.Rounding.Floor);
    }

    function convertToShares(uint256 assets, uint256 epochId)
        public
        view
        returns (uint256)
    {
        return _convertToShares(assets, epochId, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares, uint256 epochId) public view returns (uint256) {
        return _convertToAssets(shares, epochId, Math.Rounding.Floor);
    }

    // @dev See {IERC4626-convertToAssets}.
    // @notice The `convertToAssets` function is used to calculate underlying
    // assets amount received in exchange of the specified amount of shares.
    // @param shares The shares amount to be converted into underlying assets.
    // @return Amount of assets received in exchange of the specified shares
    // amount.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, epochNonce, Math.Rounding.Floor);
    }

    // @dev The `maxDeposit` function is used to calculate the maximum deposit.
    // @notice If the vault is locked or paused, users are not allowed to mint,
    // the maxMint is 0.
    // @ param _ The address of the receiver.
    // @return Amount of the maximum underlying assets deposit amount.
    function maxDeposit(address) public view returns (uint256) {
        return isOpen() && !paused() ? type(uint256).max : 0;
    }

    // @dev The `maxMint` function is used to calculate the maximum amount of
    // shares you can mint.
    // @notice If the vault is locked or paused, the maxMint is 0.
    // @ param _ The address of the receiver.
    // @return Amount of the maximum shares mintable for the specified address.

    function maxMint(address) public view returns (uint256) {
        return isOpen() && !paused() ? type(uint256).max : 0;
    }

    // @dev The `maxWithdraw` function is used to calculate the maximum amount
    // of withdrawable underlying assets.
    // @notice If the function is called during the lock period the maxWithdraw
    // is `0`.
    // @param owner The address of the owner.
    // @return Amount of the maximum number of withdrawable underlying assets.
    function maxWithdraw(address owner) public view returns (uint256) {
        return isOpen() && !paused() ? _convertToAssets(balanceOf(owner), Math.Rounding.Floor)
            : 0;
    }

    // @dev The `maxRedemm` function is used to calculate the maximum amount of
    // redeemable shares.
    // @notice If the function is called during the lock period the maxRedeem is
    // `0`.
    // @param owner The address of the owner.
    // @return Amount of the maximum number of redeemable shares.
    function maxRedeem(address owner) public view returns (uint256) {
        return isOpen() && !paused() ? balanceOf(owner) : 0;
    }

    // @dev The `previewDeposit` function is used to calculate shares amount
    // received in exchange of the specified underlying amount.
    // @param assets The underlying assets amount to be converted into shares.
    // @return Amount of shares received in exchange of the specified underlying
    // assets amount.
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    // @dev The `previewMint` function is used to calculate the underlying asset
    // amount received in exchange of the specified amount of shares.
    // @param shares The shares amount to be converted into underlying assets.
    // @return Amount of underlying assets received in exchange of the specified
    // amount of shares.
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    // @dev The `previewWithdraw` function is used to calculate the shares
    // amount received in exchange of the specified underlying amount.
    // @param assets The underlying assets amount to be converted into shares.
    // @return Amount of shares received in exchange of the specified underlying
    // assets amount.
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    // @dev The `previewRedeem` function is used to calculate the underlying
    // assets amount received in exchange of the specified amount of shares.
    // @param shares The shares amount to be converted into underlying assets.
    // @return Amount of underlying assets received in exchange of the specified
    // amount of shares.
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    // @dev The `deposit` function is used to deposit underlying assets into the
    // vault.
    // @notice The `deposit` function is used to deposit underlying assets into
    // the vault.
    // @param assets The underlying assets amount to be converted into shares.
    // @param receiver The address of the shares receiver.
    // @return Amount of shares received in exchange of the
    // specified underlying assets amount.
    function deposit(uint256 assets, address receiver)
        public
        returns (uint256)
    {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 sharesAmount = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, sharesAmount);

        return sharesAmount;
    }

    // @dev The `depositMinShares` function is used to deposit underlying assets
    // into the vault. It also checks that the amount of shares minted is greater
    // or equal to the specified minimum amount.
    // @param assets The underlying assets amount to be converted into shares.
    // @param receiver The address of the shares receiver.
    // @param minShares The minimum amount of shares to be minted.
    // @return Amount of shares received in exchange of the specified underlying
    // assets amount.
    function depositMinShares(
        uint256 assets,
        address receiver,
        uint256 minShares
    ) public returns (uint256) {
        uint256 sharesAmount = deposit(assets, receiver);
        if (sharesAmount < minShares) {
            revert ERC4626NotEnoughSharesMinted(
                receiver, sharesAmount, minShares
            );
        }
        return sharesAmount;
    }

    // @dev The `mint` function is used to mint the specified amount of shares in
    // exchange of the corresponding assets amount from owner.
    // @param shares The shares amount to be converted into underlying assets.
    // @param receiver The address of the shares receiver.
    // @return Amount of underlying assets deposited in exchange of the specified
    // amount of shares.
    function mint(uint256 shares, address receiver)
        public
        whenNotPaused
        returns (uint256)
    {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assetsAmount = previewMint(shares);
        _deposit(_msgSender(), receiver, assetsAmount, shares);

        return assetsAmount;
    }

    // @dev The `mintMaxAssets` function is used to mint the specified amount of
    // shares in exchange of the corresponding underlying assets amount from
    // owner. It also checks that the amount of assets deposited is less or equal
    // to the specified maximum amount.
    // @param shares The shares amount to be converted into underlying assets.
    // @param receiver The address of the shares receiver.
    // @param maxAssets The maximum amount of assets to be deposited.
    // @return Amount of underlying assets deposited in exchange of the specified
    // amount of shares.
    function mintMaxAssets(uint256 shares, address receiver, uint256 maxAssets)
        public
        returns (uint256)
    {
        uint256 assetsAmount = mint(shares, receiver);
        if (assetsAmount > maxAssets) {
            revert ERC4626TooMuchAssetsDeposited(
                receiver, assetsAmount, maxAssets
            );
        }

        return assetsAmount;
    }

    // @dev The `withdraw` function is used to withdraw the specified underlying
    // assets amount in exchange of a proportional amount of shares.
    // @param assets The underlying assets amount to be converted into shares.
    // @param receiver The address of the shares receiver.
    // @param owner The address of the owner.
    // @return Amount of shares received in exchange of the specified underlying
    // assets amount.
    function withdraw(uint256 assets, address receiver, address owner)
        external
        whenNotPaused
        returns (uint256)
    {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 sharesAmount = previewWithdraw(assets);
        _withdraw(receiver, owner, assets, sharesAmount);

        return sharesAmount;
    }

    // @dev The `redeem` function is used to redeem the specified amount of
    // shares in exchange of the corresponding underlying assets amount from
    // owner.
    // @param shares The shares amount to be converted into underlying assets.
    // @param receiver The address of the shares receiver.
    // @param owner The address of the owner.
    // @return Amount of underlying assets received in exchange of the specified
    // amount of shares.
    function redeem(uint256 shares, address receiver, address owner)
        public
        whenNotPaused
        returns (uint256)
    {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assetsAmount = previewRedeem(shares);
        _withdraw(receiver, owner, assetsAmount, shares);

        return assetsAmount;
    }

    // function totalAssets() public view returns (uint256) {
    //     return isOpen() ? totalAssets : _lastSavedBalance;
    // }


    // @dev Internal conversion function (from assets to shares) with support
    // for rounding direction.
    // @param assets Theunderlying assets amount to be converted into shares.
    // @param rounding The rounding direction.
    // @return Amount of shares received in exchange of the specified underlying
    // assets amount.
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        uint256 _totalAssets = totalAssets;
        return _totalAssets == 0 ? 0 :
            assets.mulDiv(totalSupply(), _totalAssets, rounding);
    }

    function _convertToShares(
        uint256 assets,
        uint256 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        uint256 _totalAssets = epoch[requestId].totalAssetsSnapshot;
        return _totalAssets == 0 || requestId == epochNonce ? 0 :
            assets.mulDiv(
                epoch[requestId].totalSupplySnapshot,
                _totalAssets,
                rounding
            );
    }

    // @dev Internal conversion function (from shares to assets) with support
    // for rounding direction.
    // @param shares The shares amount to be converted into underlying assets.
    // @param rounding The rounding direction.
    // @return Amount of underlying assets received in exchange of the
    // specified amount of shares.
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        uint256 totalSupply = totalSupply();
        return totalSupply == 0 ? 0
            : shares.mulDiv(totalAssets, totalSupply, rounding);
    }

    function _convertToAssets(
        uint256 shares,
        uint256 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        uint256 totalSupply = epoch[requestId].totalSupplySnapshot;
        return totalSupply == 0 || requestId == epochNonce ? 0:
            shares.mulDiv(
                epoch[requestId].totalAssetsSnapshot,
                totalSupply,
                rounding
            );
    }

    // @dev The `_deposit` function is used to deposit the specified underlying
    // assets amount in exchange of a proportionnal amount of shares.
    // @param caller The address of the caller.
    // @param receiver The address of the shares receiver.
    // @param assets The underlying assets amount to be converted into shares.
    // @param shares The shares amount to be converted into underlying assets.
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal {
        // If _asset is ERC777, transferFrom can trigger a reentrancy BEFORE the
        // transfer happens through the tokensToSend hook. On the other hand,
        // the tokenReceived hook, that is triggered after the transfer,calls
        // the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any
        // reentrancy would happen before the assets are transferred and before
        // the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        _asset.safeTransferFrom(caller, address(this), assets);
        totalAssets += assets;
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    // @dev The function `_withdraw` is used to withdraw the specified
    // underlying assets amount in exchange of a proportionnal amount of shares by
    // specifying all the params.
    // @notice The `withdraw` function is used to withdraw the specified
    // underlying assets amount in exchange of a proportionnal amount of shares.
    // @param receiver The address of the shares receiver.
    // @param owner The address of the owner.
    // @param assets The underlying assets amount to be converted into shares.
    // @param shares The shares amount to be converted into underlying assets.
    function _withdraw(
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal {
        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        _burn(owner, shares);
        totalAssets -= assets;
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /**
     * ####################################
     *   AMPHOR SYNTHETIC RELATED FUNCTIONS
     *  ####################################
     */

    // @dev The `close` function is used to close the vault.
    // It is the only way to lock the vault. It can only be called by the owner
    // of the contract (`onlyOwner` modifier).
    function close() external onlyOwner {
        if (!isOpen()) revert VaultIsLocked();

        uint256 _totalAssets = totalAssets;
        if (_totalAssets == 0) revert VaultIsEmpty();

        _lastSavedBalance = _totalAssets;

        _asset.safeTransfer(owner(), _lastSavedBalance);

        emit EpochStart(block.timestamp, _lastSavedBalance, totalSupply());
    }

    // @dev The `open` function is used to open the vault.
    // @notice The `end` function is used to end the lock period of the vault.
    // It can only be called by the owner of the contract (`onlyOwner` modifier)
    // and only when the vault is locked.
    // If there are profits, the performance fees are taken and sent to the
    // owner of the contract.
    // @param assetReturned The underlying assets amount to be deposited into
    // the vault.
    function open(uint256 assetReturned) external onlyOwner whenClosed {
        if (isOpen()) revert VaultIsOpen();

        uint256 fees;

        if (assetReturned > _lastSavedBalance && feesInBps > 0) {
            uint256 profits;
            unchecked {
                profits = assetReturned - _lastSavedBalance;
            }
            fees = (profits).mulDiv(feesInBps, BPS_DIVIDER, Math.Rounding.Ceil);
        }

        _asset.safeTransferFrom(
            _msgSender(), address(this), assetReturned - fees
        );

        emit EpochEnd(
            block.timestamp,
            _lastSavedBalance,
            assetReturned,
            fees,
            totalSupply()
        );

        _lastSavedBalance = 0; // deposit and redeem will use this value to calculate the shares price
        
        /////////////////////////////
        // Pending deposits treatment
        /////////////////////////////
        uint256 pendingDeposit = totalPendingDepositRequest; // get the underlying of the pending deposits
        deposit(pendingDeposit, address(this));
        emit AsyncDeposit(epochNonce, pendingDeposit, pendingDeposit);

        ////////////////////////////
        // Pending redeem treatment
        ////////////////////////////
        uint256 pendingRedeem = totalPendingRedeemRequest; // get the shares of the pending withdraws
        redeem(pendingRedeem, address(this), address(this));
        emit AsyncRedeem(epochNonce, pendingRedeem, pendingRedeem);

        totalPendingDepositRequest = 0;
        totalPendingRedeemRequest = 0;

        epoch[epochNonce].totalSupplySnapshot = totalSupply();
        epoch[epochNonce].totalAssetsSnapshot = totalAssets;
        epochNonce++;
        emit EpochStart(block.timestamp, _lastSavedBalance, totalSupply());
        _lastSavedBalance = 0;
    }

    function restruct(uint256 virtualReturnedAsset) external onlyOwner {
        emit EpochEnd(
            block.timestamp,
            _lastSavedBalance,
            virtualReturnedAsset,
            0,
            totalSupply()
        );
        emit EpochStart(block.timestamp, _lastSavedBalance, totalSupply());
    }

    /**
     * ####################################
     *   AMPHOR SYNTHETIC RELATED FUNCTIONS
     *  ####################################
     */

    // @dev The `setFees` function is used to modify the protocol fees.
    // @notice The `setFees` function is used to modify the perf fees.
    // It can only be called by the owner of the contract (`onlyOwner` modifier).
    // It can't exceed 30% (3000 in BPS).
    // @param newFees The new perf fees to be applied.
    function setFees(uint16 newFees) external onlyOwner {
        if (!isOpen()) revert VaultIsLocked();
        if (newFees > 3000) revert FeesTooHigh();
        feesInBps = newFees;
        emit FeesChanged(feesInBps, newFees);
    }

    // TODO: Finish to implement this correclty

    // @dev The `claimToken` function is used to claim other tokens that have
    // been sent to the vault.
    // @notice The `claimToken` function is used to claim other tokens that have
    // been sent to the vault.
    // It can only be called by the owner of the contract (`onlyOwner` modifier).
    // @param token The IERC20 token to be claimed.

    function claimToken(IERC20 token) external onlyOwner {
        if (token == _asset) {
            revert CannotClaimAsset();
        }
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    /**
     * ####################################
     *   Pausability RELATED FUNCTIONS
     *  ####################################
     */

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Pausable)
        whenNotPaused
    {
        super._update(from, to, value);
    }

    /**
     * ###########################
     *   PERMIT2 RELATED FUNCTIONS
     *  ###########################
     */

    // Deposit some amount of an ERC20 token into this contract
    // using Permit2.
    function execPermit2(Permit2Params calldata permit2Params) internal {
        // Transfer tokens from the caller to ourselves.
        permit2.permitTransferFrom(
            // The permit message.
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: permit2Params.token,
                    amount: permit2Params.amount
                }),
                nonce: permit2Params.nonce,
                deadline: permit2Params.deadline
            }),
            // The transfer recipient and amount.
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: permit2Params.amount
            }),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            _msgSender(),
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            permit2Params.signature
        );
    }

    function requestDepositWithPermit2(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data,
        Permit2Params calldata permit2Params
    ) external {
        if (_asset.allowance(owner, address(this)) < assets) {
            execPermit2(permit2Params);
        }
        return requestDeposit(assets, receiver, owner, data);
    }

    function depositWithPermit2(
        uint256 assets,
        address receiver,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        if (_asset.allowance(_msgSender(), address(this)) < assets) {
            execPermit2(permit2Params);
        }
        return deposit(assets, receiver);
    }

    function depositWithPermit2MinShares(
        uint256 assets,
        address receiver,
        uint256 minShares,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        if (_asset.allowance(_msgSender(), address(this)) < assets) {
            execPermit2(permit2Params);
        }
        return depositMinShares(assets, receiver, minShares);
    }

    function mintWithPermit2(
        uint256 shares,
        address receiver,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        if (_asset.allowance(_msgSender(), address(this)) < previewMint(shares))
        {
            execPermit2(permit2Params);
        }
        return mint(shares, receiver);
    }

    function mintWithPermit2MaxAssets(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        Permit2Params calldata permit2Params
    ) external returns (uint256) {
        if (_asset.allowance(_msgSender(), address(this)) < previewMint(shares))
        {
            execPermit2(permit2Params);
        }
        return mintMaxAssets(shares, receiver, maxAssets);
    }

    function isOpen() public view returns (bool) {
        return _isOpen;
    }
}
