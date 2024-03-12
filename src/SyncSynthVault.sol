//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    ERC20Upgradeable,
    IERC20
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ERC20PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ERC20Permit } from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/*
 *         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@%=::::::=%@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@*=#=--=*=*@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:*=    =#:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:@@    @@:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:@@    @@:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:@@    @@:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@*-.    .-*@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@*        *@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@.         .@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@*  Amphor  *@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@*==========#@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@+==========*@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@*   Sync   *@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@%  Vault  %@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@=        +@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@%       %@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@=      =@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@%     .@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@@=    =@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@@%----%@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@%+:::::+%@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@########@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 *
 *            d8888                        888
 *           d88888                        888
 *          d88P888                        888
 *         d88P 888 88888b.d88b.  88888b.  88888b.   .d88b.  888d888
 *        d88P  888 888 "888 "88b 888 "88b 888 "88b d88""88b 888P"
 *       d88P   888 888  888  888 888  888 888  888 888  888 888
 *      d8888888888 888  888  888 888 d88P 888  888 Y88..88P 888
 *     d88P     888 888  888  888 88888P"  888  888  "Y88P"  888.io
 *                                888
 *                                888
 *                                888
 */

/*
 * ########
 * # LIBS #
 * ########
*/
using Math for uint256; // only used for `mulDiv` operations.
using SafeERC20 for IERC20; // `safeTransfer` and `safeTransferFrom`

struct PermitParams {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}

uint256 constant BPS_DIVIDER = 10_000;
uint16 constant MAX_FEES = 3000; // 30%

abstract contract SyncSynthVault is
    IERC4626,
    Ownable2StepUpgradeable,
    ERC20PermitUpgradeable,
    ERC20PausableUpgradeable
{
    /*
     * ####################################
     * # AMPHOR SYNTHETIC RELATED STORAGE #
     * ####################################
    */

    // @return Amount of the perf fees applied on the positive yield.
    uint16 public feesInBps;
    uint16 internal _maxDrawdown; // guardrail
    IERC20 internal _asset; // underlying asset
    bool public vaultIsOpen; // vault is open or closed
    uint256 public lastSavedBalance; // last saved balance
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable

    /*
     * ##########
     * # EVENTS #
     * ##########
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

    /*
     * ##########
     * # ERRORS #
     * ##########
     */
    error VaultIsClosed();
    error VaultIsOpen();
    error FeesTooHigh();
    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
    error VaultIsEmpty(); // We cannot start an epoch with an empty vault
    error MaxDrawdownReached();

    uint8 private _underlyingDecimals;

    /*
     * ##############################
     * # AMPHOR SYNTHETIC FUNCTIONS #
     * ##############################
     */
    modifier whenClosed() {
        if (vaultIsOpen) revert VaultIsOpen();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        //_disableInitializers();
    }

    function initialize(
        uint16 fees,
        address owner,
        IERC20 underlying,
        string memory name,
        string memory symbol
    )
        public
        virtual
        onlyInitializing
    {
        if (fees > MAX_FEES) revert FeesTooHigh();
        feesInBps = fees;
        vaultIsOpen = true;
        _maxDrawdown = 3000; // 30%
        _asset = underlying;
        _underlyingDecimals =
            uint8(IERC20Metadata(address(underlying)).decimals());
        __ERC20_init(name, symbol);
        __Ownable_init(owner);
        __ERC20Permit_init(name);
        __ERC20Pausable_init();
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
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        external
        whenNotPaused
        returns (uint256)
    {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 sharesAmount = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, sharesAmount);

        return sharesAmount;
    }

    /*
     * #################################
     * # Pausability RELATED FUNCTIONS #
     * #################################
    */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /*
     * ######################################
     * # AMPHOR SYNTHETIC RELATED FUNCTIONS #
     * ######################################
    */

    /**
     * @dev The `setFee` function is used to modify the protocol fees.
     * @notice The `setFee` function is used to modify the perf fees.
     * It can only be called by the owner of the contract (`onlyOwner`
     * modifier).
     * It can't exceed 30% (3000 in BPS).
     * @param newFee The new perf fees to be applied.
     */
    function setFee(uint16 newFee) external onlyOwner {
        if (!vaultIsOpen) revert VaultIsClosed();
        if (newFee > MAX_FEES) revert FeesTooHigh();
        feesInBps = newFee;
        emit FeesChanged(feesInBps, newFee);
    }

    function setMaxDrawdown(uint16 newMaxDrawdown) external onlyOwner {
        if (newMaxDrawdown > 10_000) revert MaxDrawdownReached();
        _maxDrawdown = newMaxDrawdown;
    }

    function open(uint256 assetReturned) external virtual;
    function close() external virtual;

    /*
     * #################################
     * #   Permit RELATED FUNCTIONS    #
     * #################################
    */

    /**
     * @dev The `depositWithPermit` function is used to deposit underlying
     * assets
     * into the vault using a permit for approval.
     * @param assets The underlying assets amount to be converted into
     * shares.
     * @param receiver The address of the shares receiver.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function depositWithPermit(
        uint256 assets,
        address receiver,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_asset.allowance(msg.sender, address(this)) < assets) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return deposit(assets, receiver);
    }

    /**
     * @dev See {IERC4626-deposit}
     * @notice The `deposit` function is used to deposit underlying assets into
     * the vault.
     * @param assets The underlying assets amount to be converted into shares.
     * @param receiver The address of the shares receiver.
     * @return Amount of shares received in exchange of the
     * specified underlying assets amount.
     */
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        whenNotPaused
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
     * @dev The `mint` function is used to mint the specified amount of shares
     * in
     * exchange of the corresponding assets amount from owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @return Amount of underlying assets deposited in exchange of the
     * specified
     * amount of shares.
     */
    function mint(
        uint256 shares,
        address receiver
    )
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
    // tree done
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        whenNotPaused
        returns (uint256)
    {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assetsAmount = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assetsAmount, shares);

        return assetsAmount;
    }

    // @return address of the underlying asset.
    function asset() public view returns (address) {
        return address(_asset);
    }

    // @dev See {IERC4626-convertToShares}.
    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function sharesBalanceInAsset(address owner)
        public
        view
        returns (uint256)
    {
        return convertToAssets(balanceOf(owner));
    }

    // @dev See {IERC4626-convertToAssets}.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /*
    * @dev The `maxDeposit` function is used to calculate the maximum deposit.
     * @notice If the vault is locked or paused, users are not allowed to
     * deposit,
     * the maxDeposit is 0.
     * @return Amount of the maximum underlying assets deposit amount.
     */
    function maxDeposit(address) public view returns (uint256) {
        return vaultIsOpen && !paused() ? type(uint256).max : 0;
    }

    /**
     * @dev The `maxMint` function is used to calculate the maximum amount of
     * shares you can mint.
     * @notice If the vault is locked or paused, the maxMint is 0.
     * @return Amount of the maximum shares mintable for the specified address.
     */
    function maxMint(address) public view returns (uint256) {
        return vaultIsOpen && !paused() ? type(uint256).max : 0;
    }

    /**
     * @dev See {IERC4626-maxWithdraw}.
     * @notice If the function is called during the lock period the maxWithdraw
     * is `0`.
     * @return Amount of the maximum number of withdrawable underlying assets.
     */
    function maxWithdraw(address owner) public view returns (uint256) {
        return vaultIsOpen && !paused()
            ? _convertToAssets(balanceOf(owner), Math.Rounding.Floor)
            : 0;
    }

    /**
     * @dev See {IERC4626-maxRedeem}.
     * @notice If the function is called during the lock period the maxRedeem is
     * `0`;
     * @param owner The address of the owner.
     * @return Amount of the maximum number of redeemable shares.
     */
    function maxRedeem(address owner) public view returns (uint256) {
        return vaultIsOpen && !paused() ? balanceOf(owner) : 0;
    }

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @dev See {IERC4626-previewMint}.
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /**
     * @dev See {IERC4626-previewWithdraw}
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /**
     * @dev See {IERC4626-previewRedeem}
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function totalAssets() public view returns (uint256) {
        if (vaultIsOpen) return _asset.balanceOf(address(this));
        else return _asset.balanceOf(address(this)) + lastSavedBalance;
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
    )
        internal
    {
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
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev The function `_withdraw` is used to withdraw the specified
     * underlying assets amount in exchange of a proportionnal amount of shares
     * by
     * specifying all the params.
     * @notice The `withdraw` function is used to withdraw the specified
     * underlying assets amount in exchange of a proportionnal amount of shares.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @param assets The underlying assets amount to be converted into shares.
     * @param shares The shares amount to be converted into underlying assets.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    )
        internal
    {
        if (caller != owner) _spendAllowance(owner, caller, shares);

        _burn(owner, shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        ERC20PausableUpgradeable._update(from, to, value);
    }

    function execPermit(
        address owner,
        address spender,
        PermitParams calldata permitParams
    )
        internal
    {
        ERC20Permit(address(_asset)).permit(
            owner,
            spender,
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s
        );
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support
     * for rounding direction.
     * @param assets Theunderlying assets amount to be converted into shares.
     * @param rounding The rounding direction.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + 1, totalAssets() + 1, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support
     * for rounding direction.
     * @param shares The shares amount to be converted into underlying assets.
     * @param rounding The rounding direction.
     * @return Amount of underlying assets received in exchange of the
     * specified amount of shares.
     */
    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 1, rounding);
    }

    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20Metadata)
        returns (uint8)
    {
        return _underlyingDecimals;
    }
}
