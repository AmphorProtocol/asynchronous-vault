//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

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
import {SafeERC20} from "./SynthVaultRequestReceipt.sol";
import {IPermit2, ISignatureTransfer} from "permit2/src/interfaces/IPermit2.sol";

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}

struct Epoch {
    uint256 totalDeposits;
    uint256 totalRedeems;
    uint256 sharePrice; // LP/underlying -> rounded correctly
    mapping(address => uint256) deposit; // TODO: name to change
    mapping(address => uint256) redeem; // TODO: name to change
}

contract SynthVault is IERC7540, ERC20Pausable, Ownable2Step, ERC20Permit {

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
     * @dev The vault is in locked state. Emitted if the tx cannot happen in
     * this state.
     */
    error VaultIsLocked();

    /**
     * @dev The vault is in open state. Emitted if the tx cannot happen in this
     * state.
     */
    error VaultIsOpen();

    /**
     * @dev The rules doesn't allow the perf fees to be higher than 30.00%.
     */
    error FeesTooHigh();

    /**
     * @dev Claiming the underlying assets is not allowed.
     */
    error CannotClaimAsset();

    /**
     * @dev Attempted to deposit more underlying assets than the max amount for
     * `receiver`.
     */
    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );

    /**
     * @dev Attempted to mint more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /**
     * @dev Attempted to withdraw more underlying assets than the max amount for
     * `receiver`.
     */
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /**
     * @dev Attempted to redeem more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /**
     * @dev Attempted to mint less shares than the min amount for `receiver`.
     * This error is only thrown when the `depositMinShares` function is used.
     * @notice The `depositMinShares` function is used to deposit underlying
     * assets into the vault. It also checks that the amount of shares minted is
     * greater or equal to the specified minimum amount.
     * @param owner The address of the owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param minShares The minimum amount of shares to be minted.
     */
    error ERC4626NotEnoughSharesMinted(
        address owner, uint256 shares, uint256 minShares
    );

    /**
     * @dev Attempted to withdraw more underlying assets than the max amount for
     * `receiver`.
     * This error is only thrown when the `mintMaxAssets` function is used.
     * @notice The `mintMaxAssets` function is used to mint the specified amount
     * of shares in exchange of the corresponding underlying assets amount from
     * owner. It also checks that the amount of assets deposited is less or
     * equal to the specified maximum amount.
     * @param owner The address of the owner.
     * @param assets The underlying assets amount to be converted into shares.
     * @param maxAssets The maximum amount of assets to be deposited.
     */
    error ERC4626TooMuchAssetsDeposited(
        address owner, uint256 assets, uint256 maxAssets
    );

    /*
     ####################################
      GENERAL PERMIT2 RELATED ATTRIBUTES
     ####################################
    */

    // The canonical permit2 contract.
    IPermit2 public immutable permit2;

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

    IERC20 internal immutable _asset;
    uint256 public epochNonce = 1; // in order to start at epoch 1, otherwise users might try to claim epoch -1 requests
    uint256 public totalAssets; // total working assets (in the strategy), not including pending withdrawals money

    Epoch[] public epochs; // TODO: mapping or array? // TODO: mapping or array?
    mapping(address => uint256) lastDepositRequest; // user => epochNonce
    mapping(address => uint256) lastRedeemRequest; // user => epochNonce

    bool vaultIsOpen = true;

    /**
     * @dev The total underlying assets amount just before the lock period.
     * @return Amount of the total underlying assets just before the last vault
     * locking.
     */
    uint256 public lastSavedBalance; // TODO remove this shit

    /*
     ############################
      AMPHOR SYNTHETIC FUNCTIONS
     ############################
    */

    constructor(
        ERC20 underlying,
        IPermit2 _permit2
    ) ERC20(name, symbol) Ownable(_msgSender()) ERC20Permit(name) {
        _asset = IERC20(underlying);
        permit2 = _permit2;
    }

    function requestDeposit(uint256 assets, address receiver, address owner, bytes memory data) public whenNotPaused returns (uint256) {
        // Check if the user has a claimable request
        uint256 lastRequestNonce = lastDepositRequest[receiver];
        uint256 lastRequestBalance = epochs[lastRequestNonce].deposit[receiver];
        bool hasClaimableRequest = lastRequestBalance > 0 && lastRequestNonce != epochNonce;

        if (hasClaimableRequest) revert; // TODO: emit an error

        // Create a new request
        _createDepositRequest(assets, receiver, owner, data);

        // Return the requestId
        return epochNonce;
    }

    function _createDepositRequest(uint256 assets, address receiver, address owner, bytes memory data) internal {
        _asset.safeTransferFrom(owner, address(this), assets);
        epochs[epochNonce].totalDeposits += assets;
        epochs[epochNonce].deposit[receiver] = assets;
        lastDepositRequest[owner] = epochNonce;

        if (data.length > 0)
            require(
                ERC7540Receiver(receiver).onERC7540DepositReceived(
                    _msgSender(),
                    owner,
                    epochNonce, data
                ) == ERC7540Receiver.onERC7540DepositReceived.selector,
                "receiver failed"
            );

        emit DepositRequest(receiver, owner, epochNonce, _msgSender(), assets);
    }

    function claimAndRequestDeposit(uint256 assets, address receiver, address owner, bytes memory data) external whenNotPaused {
        uint256 lastRequestNonce = lastDepositRequest[receiver];
        _deposit(owner, receiver, lastRequestNonce, epochs[lastRequestNonce].deposit[receiver]);
        requestDeposit(assets, receiver, owner);
    }

    function claimAndRequestRedeem(uint256 shares, address receiver, address owner, bytes memory data) external whenNotPaused {
        uint256 lastRequestNonce = lastRedeemRequest[receiver];
        // _redeem(owner, receiver, lastRequestNonce, epochs[lastRequestNonce].redeem[receiver]); // TODO
        requestRedeem(shares, receiver, owner);
    }

    function withdrawDepositRequest(uint256 assets, address receiver, address owner) external whenNotPaused {
        uint256 lastRequestNonce = lastDepositRequest[owner];
        epochs[lastRequestNonce].deposit[owner] -= assets;
        epochs[lastRequestNonce].totalDeposits -= assets; 
        _asset.safeTransfer(receiver, assets);

        // TODO: emit an event
    }

    function pendingDepositRequest(address owner) external view returns (uint256 assets) {
        return epochs[epochNonce].deposit[owner];
    }

    function requestRedeem(uint256 shares, address receiver, address owner, bytes memory data) public whenNotPaused returns (uint256) {
        // Check if the user has a claimable request
        uint256 lastRequestNonce = lastRedeemRequest[receiver];
        uint256 lastRequestBalance = epochs[lastRequestNonce].redeem[receiver];
        bool hasClaimableRequest = lastRequestBalance > 0 && lastRequestNonce != epochNonce;

        if (hasClaimableRequest) revert; // TODO: emit an error

        // Create a new request
        _createRedeemRequest(shares, receiver, owner, data);

        // Return the requestId
        return epochNonce;
    }

    function _createRedeemRequest(uint256 shares, address receiver, address owner, bytes memory data) internal {
        transferFrom(owner, address(this), shares);
        epochs[epochNonce].totalRedeems += shares;
        epochs[epochNonce].redeem[receiver] += shares;
        lastRedeemRequest[owner] = epochNonce;

        if (data.length > 0)
            require(
                ERC7540Receiver(receiver).onERC7540RedeemReceived(
                    _msgSender(),
                    owner,
                    epochNonce,
                    data
                ) == ERC7540Receiver.onERC7540RedeemReceived.selector,
                "receiver failed"
            );

        emit DepositRequest(receiver, owner, epochNonce, _msgSender(), shares);
    }

    function withdrawRedeemRequest(uint256 shares, address receiver, address owner) external whenNotPaused {
        uint256 lastRequestNonce = lastRedeemRequest[owner];

        epochs[lastRequestNonce].redeem[owner] -= shares;
        epochs[lastRequestNonce].totalRedeems -= shares;
        transfer(receiver, shares);

        // TODO: emit an event
    }

    function pendingRedeemRequest(address owner) external view returns (uint256 shares) {
        return epochs[epochNonce].redeem[owner];
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
        return _convertToShares(assets, Math.Rounding.Down);
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
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /**
     * @dev The `maxDeposit` function is used to calculate the maximum deposit.
     * @notice If the vault is locked or paused, users are not allowed to mint,
     * the maxMint is 0.
     * @ param _ The address of the receiver.
     * @return Amount of the maximum underlying assets deposit amount.
     */
    function maxDeposit(address) public view returns (uint256) {
        return !vaultIsOpen || paused() ? 0 : type(uint256).max;
    }

    /**
     * @dev The `maxMint` function is used to calculate the maximum amount of
     * shares you can mint.
     * @notice If the vault is locked or paused, the maxMint is 0.
     * @ param _ The address of the receiver.
     * @return Amount of the maximum shares mintable for the specified address.
     */
    function maxMint(address) public view returns (uint256) {
        return !vaultIsOpen || paused() ? 0 : type(uint256).max;
    }

    /**
     * @dev The `maxWithdraw` function is used to calculate the maximum amount
     * of withdrawable underlying assets.
     * @notice If the function is called during the lock period the maxWithdraw
     * is `0`.
     * @param owner The address of the owner.
     * @return Amount of the maximum number of withdrawable underlying assets.
     */
    function maxWithdraw(address owner) public view returns (uint256) {
        return vaultIsOpen
            ? _convertToAssets(balanceOf(owner), Math.Rounding.Down)
            : 0;
    }

    /**
     * @dev The `maxRedemm` function is used to calculate the maximum amount of
     * redeemable shares.
     * @notice If the function is called during the lock period the maxRedeem is
     * `0`.
     * @param owner The address of the owner.
     * @return Amount of the maximum number of redeemable shares.
     */
    function maxRedeem(address owner) public view returns (uint256) {
        return vaultIsOpen ? balanceOf(owner) : 0;
    }

    /**
     * @dev The `previewDeposit` function is used to calculate shares amount
     * received in exchange of the specified underlying amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    /**
     * @dev The `previewMint` function is used to calculate the underlying asset
     * amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Up);
    }

    /**
     * @dev The `previewWithdraw` function is used to calculate the shares
     * amount received in exchange of the specified underlying amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Up);
    }

    /**
     * @dev The `previewRedeem` function is used to calculate the underlying
     * assets amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /**
     * @dev The `deposit` function is used to deposit underlying assets into the
     * vault.
     * @notice The `deposit` function is used to deposit underlying assets into
     * the vault.
     * @param assets The underlying assets amount to be converted into shares.
     * @param receiver The address of the shares receiver.
     * @return Amount of shares received in exchange of the
     * specified underlying assets amount.
     */
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

    /**
     * @dev The `depositMinShares` function is used to deposit underlying assets
     * into the vault. It also checks that the amount of shares minted is greater
     * or equal to the specified minimum amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @param receiver The address of the shares receiver.
     * @param minShares The minimum amount of shares to be minted.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
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

    /**
     * @dev The `mint` function is used to mint the specified amount of shares in
     * exchange of the corresponding assets amount from owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @return Amount of underlying assets deposited in exchange of the specified
     * amount of shares.
     */
    function mint(uint256 shares, address receiver) public returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assetsAmount = previewMint(shares);
        _deposit(_msgSender(), receiver, assetsAmount, shares);

        return assetsAmount;
    }

    /**
     * @dev The `mintMaxAssets` function is used to mint the specified amount of
     * shares in exchange of the corresponding underlying assets amount from
     * owner. It also checks that the amount of assets deposited is less or equal
     * to the specified maximum amount.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @param maxAssets The maximum amount of assets to be deposited.
     * @return Amount of underlying assets deposited in exchange of the specified
     * amount of shares.
     */
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

    /**
     * @dev The `withdraw` function is used to withdraw the specified underlying
     * assets amount in exchange of a proportional amount of shares.
     * @param assets The underlying assets amount to be converted into shares.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function withdraw(uint256 assets, address receiver, address owner)
        external
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

    /**
     * @dev The `_totalAssets` function is used to return the current assets
     * balance of the vault contract.
     * @notice The `_totalAssets` is used to know the balance of underlying of
     * the vault contract without
     * taking care of any theoretical external funds of the vault.
     * @return Amount of underlying assets balance actually contained into the
     * vault contract.
     */
    function _totalAssets() internal view returns (uint256) {
        return _asset.balanceOf(address(this));
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
            totalSupply() + 1, totalAssets() + 1, rounding
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
            totalAssets() + 1, totalSupply() + 1, rounding
        );
    }

    /**
     * @dev The `_deposit` function is used to deposit the specified underlying
     * assets amount in exchange of a proportionnal amount of shares.
     * @param caller The address of the caller.
     * @param receiver The address of the shares receiver.
     * @param assets The underlying assets amount to be converted into shares.
     * @param shares The shares amount to be converted into underlying assets.
     */
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
        SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev The function `_withdraw` is used to withdraw the specified
     * underlying assets amount in exchange of a proportionnal amount of shares by
     * specifying all the params.
     * @notice The `withdraw` function is used to withdraw the specified
     * underlying assets amount in exchange of a proportionnal amount of shares.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @param assets The underlying assets amount to be converted into shares.
     * @param shares The shares amount to be converted into underlying assets.
     */
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
        SafeERC20.safeTransfer(_asset, receiver, assets);

        emit Withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /*
     ####################################
      AMPHOR SYNTHETIC RELATED FUNCTIONS
     ####################################
    */

    /**
     * @dev The `start` function is used to start the lock period of the vault.
     * It is the only way to lock the vault. It can only be called by the owner
     * of the contract (`onlyOwner` modifier).
     */
    function start() external onlyOwner {
        if (!vaultIsOpen) revert VaultIsLocked();

        lastSavedBalance = _totalAssets();
        vaultIsOpen = false;
        _asset.safeTransfer(owner(), lastSavedBalance);

        emit EpochStart(block.timestamp, lastSavedBalance, totalSupply());
    }

    /**
     * @dev The `end` function is used to end the lock period of the vault.
     * @notice The `end` function is used to end the lock period of the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier)
     * and only when the vault is locked.
     * If there are profits, the performance fees are taken and sent to the
     * owner of the contract.
     * @param assetReturned The underlying assets amount to be deposited into
     * the vault.
     */
    function end(uint256 assetReturned) external onlyOwner {
        if (vaultIsOpen) revert VaultIsOpen();

        uint256 fees;

        if (assetReturned > lastSavedBalance && feesInBps > 0) {
            uint256 profits;
            unchecked {
                profits = assetReturned - lastSavedBalance;
            }
            fees = (profits).mulDiv(feesInBps, 10000, Math.Rounding.Up);
        }

        SafeERC20.safeTransferFrom(
            _asset, _msgSender(), address(this), assetReturned - fees
        );

        vaultIsOpen = true;

        emit EpochEnd(
            block.timestamp,
            lastSavedBalance,
            assetReturned,
            fees,
            totalSupply()
        );

        lastSavedBalance = 0;
    }

    function restruct(uint256 virtualReturnedAsset) external onlyOwner {
        emit EpochEnd(
            block.timestamp,
            lastSavedBalance,
            virtualReturnedAsset,
            0,
            totalSupply()
        );
        emit EpochStart(block.timestamp, lastSavedBalance, totalSupply());
    }

    /*
     ####################################
      AMPHOR SYNTHETIC RELATED FUNCTIONS
     ####################################
    */

    // function nextEpoch(uint256 returnedUnderlyingAmount) public onlyOwner returns (uint256) {
    //     // (end + start epochs)

    //     // TODO
    //     // 1. take fees from returnedUnderlyingAmount
    //     // 7. we update the totalAssets
    //     // 2. with the resting amount we know how much cost a share
    //     // 3. we can take the pending deposits underlying (same as this vault underlying) and mint shares
    //     // 4. we update the globalShares array for the appropriate epoch (epoch 0 request is a deposit into epoch 1...)
    //     // 5. we can take the pending withdraws shares and redeem underlying (which are shares of this vault) against this vault underlying
    //     // 6. we update the globalAssets array for the appropriate epoch (epoch 0 request is a withdraw at the end of the epoch 0...)

    //     ///////////////////////
    //     // Ending current epoch
    //     ///////////////////////
    //     uint256 fees;

    //     if (returnedUnderlyingAmount > totalAssets && feesInBps > 0) {
    //         uint256 profits;
    //         unchecked {
    //             profits = returnedUnderlyingAmount - totalAssets;
    //         }
    //         fees = (profits).mulDiv(feesInBps, 10000, Math.Rounding.Ceil);
    //     }

    //     totalAssets = returnedUnderlyingAmount - fees;

    //     // Can be done in one time at the end
    //     SafeERC20.safeTransferFrom(
    //         _asset, _msgSender(), address(this), returnedUnderlyingAmount - fees
    //     );

    //     emit EpochEnd(
    //         block.timestamp,
    //         totalAssets,
    //         returnedUnderlyingAmount,
    //         fees,
    //         totalSupply()
    //     );

    //     ///////////////////
    //     // Pending deposits
    //     ///////////////////
    //     uint256 pendingDeposit = depositRequestReceipt.nextEpoch(epochNonce); // get the underlying of the pending deposits
    //     // Updating the globalShares array
    //     globalShares.push(pendingDeposit.mulDiv(
    //         totalSupply() + 1, totalAssets + 1, Math.Rounding.Floor
    //     ));
    //     // Minting the shares
    //     _mint(address(this), globalShares[epochNonce]); // mint the shares into the vault
    //     // Update the totalAssets
    //     totalAssets += pendingDeposit;

    //     /////////////////
    //     // Pending redeem
    //     /////////////////
    //     uint256 pendingRedeem = withdrawRequestReceipt.nextEpoch(epochNonce); // get the shares of the pending withdraws
    //     // Updating the globalAssets array
    //     globalAssets.push(pendingRedeem.mulDiv(
    //         totalAssets + 1, totalSupply() + 1, Math.Rounding.Floor
    //     ));
    //     // Burn the vault shares
    //     _burn(address(this), pendingRedeem); // burn the shares from the vault
    //     // Update the totalAssets
    //     totalAssets -= globalAssets[epochNonce];

    //     //////////////////
    //     // Start new epoch
    //     //////////////////
    //     _asset.safeTransfer(owner(), totalAssets);

    //     emit EpochStart(block.timestamp, totalAssets, totalSupply());

    //     return ++epochNonce;
    // }

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

    // TODO: Finish to implement this correclty
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

    /*
     ####################################
      Pausability RELATED FUNCTIONS
     ####################################
    */
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) whenNotPaused {
        super._update(from, to, value);
    }

    /*
     ###########################
      PERMIT2 RELATED FUNCTIONS
     ###########################
    */

    // Deposit some amount of an ERC20 token into this contract
    // using Permit2.
    function execPermit2(
        Permit2Params calldata permit2Params
    ) internal {
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
        if (_asset.allowance(owner, address(this)) < assets)
            execPermit2(permit2Params);
        return requestDeposit(assets, receiver, owner, data);
    }
}