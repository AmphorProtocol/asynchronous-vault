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
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AmphorAsyncSynthVaultRequestLPImp} from "./AmphorAsyncSynthVaultRequestLPImp.sol";


contract AmphorAsyncSynthVaultImp is IERC7540, ERC20, ERC20Permit, Ownable2Step, Pausable {

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
     #####################################
      AMPHOR SYNTHETIC RELATED ATTRIBUTES
     #####################################
    */

    /**
     * @dev The perf fees applied on the positive yield.
     * @return Amount of the perf fees applied on the positive yield.
     */
    uint16 public feesInBps;

    /**
     * @dev The locking status of the vault.
     * @return `true` if the vault is open for deposits, `false` otherwise.
     */
    bool public vaultIsOpen;

    IERC20 public immutable _asset;
    uint256 public epochNonce;
    uint256 public totalSharesWidrawRequest;
    uint256 public totalDepositRequest;
    uint256 public totalAssets;
    uint256[] public bigShares;
    AmphorAsyncSynthVaultRequestLPImp public immutable depositRequestLP;
    AmphorAsyncSynthVaultRequestLPImp public immutable withdrawRequestLP;
    // mapping(address => bool) public hasPendingDepositRequest;
    // mapping(address => bool) public hasPendingWithdrawRequest;
    // mapping(address => uint256) public hasPendingDepositRequest;
    // mapping(address => uint256) public hasPendingWithdrawRequest;


    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(_msgSender()) {
        _asset = IERC20(underlying);
        depositRequestLP = new AmphorAsyncSynthVaultRequestLPImp(underlying, "amphorAsyncDepositLP", "ampAsDLP");
        withdrawRequestLP = new AmphorAsyncSynthVaultRequestLPImp(underlying, "amphorAsyncWithdrawLP", "ampAsWLP");
    }

    function nextEpoch(uint256 returnedUnderlyingAmount) external onlyOwner returns (uint256) {
        // end + start epochs
        returnedUnderlyingAmount; // tired of warning
        return ++epochNonce;
    }

    function requestDeposit(uint256 assets, address operator) external whenNotPaused {
        totalDepositRequest += assets;
        _asset.safeTransferFrom(_msgSender(), address(this), assets);
        //depositRequestLP.mint(operator, epochNonce, assets);
    }
    function withdrawDepositRequest(uint256 assets, address operator) external whenNotPaused {
        totalDepositRequest -= assets;
        // depositRequestLP.burn(operator, epochNonce, assets);
        _asset.safeTransfer(_msgSender(), assets);
    }
    function pendingDepositRequest(address operator) external view returns (uint256 assets) {
        return depositRequestLP.balanceOf(operator, epochNonce);
    }
    function requestRedeem(uint256 shares, address operator, address owner) external whenNotPaused {
        totalSharesWidrawRequest += shares;
        IERC20(this).transferFrom(operator, address(this), shares);
        // withdrawRequestLP.mint(owner, epochNonce, shares);
    }
    function withdrawRedeemRequest(uint256 shares, address operator, address owner) external whenNotPaused {
        totalSharesWidrawRequest -= shares;
        // withdrawRequestLP.burn(operator, epochNonce, shares);
        IERC20(this).transfer(owner, shares);
    }
    function pendingRedeemRequest(address operator) external view returns (uint256 shares) {
        return withdrawRequestLP.balanceOf(operator, epochNonce);
    }
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    // TODO: implement claimBatchedAssets

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
            ? _convertToAssets(balanceOf(owner), Math.Rounding.Floor)
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
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @dev The `previewMint` function is used to calculate the underlying asset
     * amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /**
     * @dev The `previewWithdraw` function is used to calculate the shares
     * amount received in exchange of the specified underlying amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /**
     * @dev The `previewRedeem` function is used to calculate the underlying
     * assets amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
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
        uint256 totalAssetsToClaim = assets;
        uint256 sharesClaimed;
        uint256[] memory allBalances = new uint256[](epochNonce);
        uint256[] memory allIds = new uint256[](epochNonce);
        for (uint256 epochIndex; totalAssetsToClaim > 0 && epochIndex < epochNonce; epochIndex++) {
            uint256 lpBalances = depositRequestLP.balanceOf(_msgSender(), epochIndex);//balanceOf[_msgSender()][epochIndex];
            if (lpBalances > 0) {
                uint256 assetsToClaim = totalAssetsToClaim > lpBalances ? lpBalances : totalAssetsToClaim;
                sharesClaimed += deposit(epochIndex, assetsToClaim, _msgSender(), receiver);
                totalAssetsToClaim -= assetsToClaim;
            }
        }

        // TODO: finish this
        // for (uint256 i = 0; i < epochNonce; i++) {
        //     uint256 amount = depositRequestLP.balanceOf(operator, epochNonce);
        //     if (amount > 0) {
        //         depositRequestLP.burn(operator, epochNonce, amount);
        //         IERC20(this).transfer(receiver, amount);
        //     }
        // }

        // uint256 sharesAmount = previewDeposit(assets);
        // _deposit(_msgSender(), receiver, assets, sharesAmount);

        // return sharesAmount;
        return 0;
    }

    function deposit (uint256 requestId, uint256 assets, address owner, address receiver)
        public
        returns (uint256 sharesAmount)
    {
        sharesAmount = previewDeposit(assets);
        _deposit(owner, receiver, requestId, assets, sharesAmount);
    }

    function claimDeposit(uint256 id, uint256 pendingShares, address owner) public {
        uint256 amount = depositRequestLP.balanceOf(owner, id);
        if (amount > 0) {
            //depositRequestLP.burn(owner, id, amount);
            IERC20(this).transfer(owner, amount);
        }
        uint256 shares = amount.mulDiv(
            bigShares[epochNonce] + 1, depositRequestLP.totalSupply(id) + 1, Math.Rounding.Floor
        );
    }

    function claimDeposits(uint256[] memory ids, uint256[] memory pendingShares, address owner) public {
        for (uint i = 0; i < ids.length; i++) claimDeposit(ids[i], pendingShares[i], owner);
    }

    /**
     * @dev The `mint` function is used to mint the specified amount of shares in
     * exchange of the corresponding assets amount from owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @return Amount of underlying assets deposited in exchange of the specified
     * amount of shares.
     */
    function mint(uint256 shares, address receiver) public whenNotPaused returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assetsAmount = previewMint(shares);
        _deposit(_msgSender(), receiver, 0, assetsAmount, shares);

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
        uint256 requestId,
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
        //depositRequestLP.burn(caller, requestId, assets);
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
    // function start() external onlyOwner {
    //     if (!vaultIsOpen) revert VaultIsLocked();

    //     lastSavedBalance = _totalAssets();
    //     vaultIsOpen = false;
    //     _asset.safeTransfer(owner(), lastSavedBalance);

    //     emit EpochStart(block.timestamp, lastSavedBalance, totalSupply());
    // }

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
    // function end(uint256 assetReturned) external onlyOwner {
    //     if (vaultIsOpen) revert VaultIsOpen();

    //     uint256 fees;

    //     if (assetReturned > lastSavedBalance && feesInBps > 0) {
    //         uint256 profits;
    //         unchecked {
    //             profits = assetReturned - lastSavedBalance;
    //         }
    //         fees = (profits).mulDiv(feesInBps, 10000, Math.Rounding.Ceil);
    //     }

    //     SafeERC20.safeTransferFrom(
    //         _asset, _msgSender(), address(this), assetReturned - fees
    //     );

    //     vaultIsOpen = true;

    //     emit EpochEnd(
    //         block.timestamp,
    //         lastSavedBalance,
    //         assetReturned,
    //         fees,
    //         totalSupply()
    //     );

    //     lastSavedBalance = 0;
    // }

    // function restruct(uint256 virtualReturnedAsset) external onlyOwner {
    //     emit EpochEnd(
    //         block.timestamp,
    //         lastSavedBalance,
    //         virtualReturnedAsset,
    //         0,
    //         totalSupply()
    //     );
    //     emit EpochStart(block.timestamp, lastSavedBalance, totalSupply());
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
}