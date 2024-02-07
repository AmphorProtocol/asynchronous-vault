//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC7540, IERC165, IERC7540Redeem } from "./interfaces/IERC7540.sol";
import { ERC7540Receiver } from "./interfaces/ERC7540Receiver.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    ERC20Upgradeable,
    IERC20
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
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
import {
    IPermit2, ISignatureTransfer
} from "permit2/src/interfaces/IPermit2.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol"; //todo remove

/**
 *         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@%=::::::=%@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@+=#---=*=*@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:*=   .-#:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:@@   .@@:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:@@   .@@:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@:@@   .@@:@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@+:.    .-*@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@+        *@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@%         .@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@+  Amphor  *@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@*==========#@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@+==========*@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@=  Async   +@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@%  Vault  .@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@=        +@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@%       .@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@=      +@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@%     .@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@@=    +@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@@@%----@@@@@@@@@@@@@@@@@@@@@@@
 *         @@@@@@@@@@@@@@@@@@@@%+::::::+@@@@@@@@@@@@@@@@@@@@@
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

struct EpochData {
    uint256 totalSupplySnapshot;
    uint256 totalAssetsSnapshot;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

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
uint16 constant MAX_DRAWDOWN = 3000; // 30%

contract SynthVault is
    IERC7540,
    ERC20PausableUpgradeable,
    Ownable2StepUpgradeable,
    ERC20PermitUpgradeable
{
    /*
     * ####################################
     * # AMPHOR SYNTHETIC RELATED STORAGE #
     * ####################################
    */

    // @return Amount of the perf fees applied on the positive yield.
    uint16 public feeInBps;
    uint16 internal _MAX_DRAWDOWN; // guardrail
    IERC20 internal _ASSET; // underlying
    uint256 public epochId;
    uint256 public totalAssets; // total underlying assets
    bool public isOpen; // vault is open or closed
    mapping(uint256 epochId => EpochData epoch) public epochs;
    mapping(address user => uint256 epochId) public lastDepositRequestId;
    mapping(address user => uint256 epochId) public lastRedeemRequestId;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IPermit2 public immutable permit2; // The canonical permit2 contract.

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

    event DecreaseDepositRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedAssets,
        uint256 newRequestedAssets
    );

    event DecreaseRedeemRequest(
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
     * ##########
     * # ERRORS #
     * ##########
     */
    error VaultIsLocked();
    error VaultIsOpen();
    error FeesTooHigh();
    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
    error ExceededMaxRedeemRequest(
        address receiver, uint256 shares, uint256 maxShares
    );
    error ExceededMaxDepositRequest(
        address receiver, uint256 assets, uint256 maxDeposit
    );
    error ERC4626NotEnoughSharesMinted(
        address owner, uint256 shares, uint256 minShares
    );
    error ERC4626TooMuchAssetsDeposited(
        address owner, uint256 assets, uint256 maxAssets
    );
    error VaultIsEmpty(); // We cannot start an epoch with an empty vault
    error ClaimableRequestPending();
    error MustClaimFirst();
    error ReceiverFailed();
    error MaxDrawdownReached();

    /**
     * ##############################
     * # AMPHOR SYNTHETIC FUNCTIONS #
     * ##############################
     */
    modifier whenClosed() {
        if (isOpen) revert VaultIsOpen();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IPermit2 _permit2) {
        _disableInitializers();
        permit2 = _permit2;
    }

    function initialize(
        uint16 fees,
        address owner,
        IERC20 underlying,
        string memory name,
        string memory symbol
    )
        public
        initializer
    {
        if (fees > MAX_FEES) revert FeesTooHigh();
        feeInBps = fees;
        isOpen = true;
        epochId = 1;
        __ERC20_init(name, symbol);
        __Ownable_init(owner);
        __ERC20Permit_init(name);
        _ASSET = IERC20(underlying);
        _MAX_DRAWDOWN = MAX_DRAWDOWN;
    }

    function isCurrentEpoch(uint256 requestId) internal view returns (bool) {
        return requestId == epochId;
    }

    function requestDeposit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    )
        public
        whenClosed
        whenNotPaused
    {
        // Check if the user has a claimable request
        uint256 lastRequestId = lastDepositRequestId[receiver];
        uint256 lastRequestBalance =
            epochs[lastRequestId].depositRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochId;

        if (hasClaimableRequest) revert MustClaimFirst();

        if (assets > maxDepositRequest(receiver)) {
            revert ExceededMaxDepositRequest(
                receiver, assets, maxDepositRequest(receiver)
            );
        }

        // Create a new request
        _createDepositRequest(assets, receiver, owner, data);
    }

    function _createDepositRequest(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    )
        internal
    {
        _ASSET.safeTransferFrom(owner, address(this), assets);
        epochs[epochId].depositRequestBalance[receiver] += assets;

        if (lastDepositRequestId[receiver] != epochId) {
            lastDepositRequestId[receiver] = epochId;
        }

        if (
            data.length > 0
                && ERC7540Receiver(receiver).onERC7540DepositReceived(
                    _msgSender(), owner, epochId, data
                ) != ERC7540Receiver.onERC7540DepositReceived.selector
        ) revert ReceiverFailed();

        emit DepositRequest(receiver, owner, epochId, _msgSender(), assets);
    }

    // tree done
    function totalPendingDeposits() public view returns (uint256) {
        return isOpen ? 0 : _ASSET.balanceOf(address(this));
    }

    // tree done
    function totalPendingRedeems() public view returns (uint256) {
        return isOpen ? 0 : balanceOf(address(this));
    }

    // tree done
    function maxDepositRequest(address) public view returns (uint256) {
        return isOpen || paused() ? 0 : type(uint256).max;
    }

    // tree done
    function maxRedeemRequest(address owner) public view returns (uint256) {
        return isOpen || paused() ? 0 : balanceOf(owner);
    }

    // tree later
    function claimAndRequestDeposit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    )
        external
    {
        claimDeposit(receiver);
        requestDeposit(assets, receiver, owner, data);
    }

    // tree later
    function claimAndRequestRedeem(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    )
        external
    {
        claimRedeem(receiver);
        requestRedeem(shares, receiver, owner, data);
    }

    // tree done
    function decreaseDepositRequest(
        uint256 assets,
        address receiver,
        address owner
    )
        external
        whenClosed
        whenNotPaused
    {
        uint256 oldBalance = epochs[epochId].depositRequestBalance[owner];
        epochs[epochId].depositRequestBalance[owner] -= assets;
        _ASSET.safeTransfer(receiver, assets);

        emit DecreaseDepositRequest(
            epochId,
            owner,
            oldBalance,
            epochs[epochId].depositRequestBalance[owner]
        );
    }

    function pendingDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        return epochs[lastDepositRequestId[owner]].depositRequestBalance[owner];
    }

    function claimableDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];
        return isCurrentEpoch(lastRequestId)
            ? 0
            : epochs[lastRequestId].depositRequestBalance[owner];
    }

    function requestRedeem(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    )
        public
        whenClosed
        whenNotPaused
    {
        // Check if the user has a claimable request
        uint256 lastRequestId = lastRedeemRequestId[receiver];
        uint256 lastRequestBalance =
            epochs[lastRequestId].redeemRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochId;

        if (hasClaimableRequest) revert MustClaimFirst();
        if (shares > maxRedeemRequest(receiver)) {
            revert ExceededMaxRedeemRequest(
                receiver, shares, maxRedeemRequest(receiver)
            );
        }

        // Create a new request
        _createRedeemRequest(shares, receiver, owner, data);
    }

    function _createRedeemRequest(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    )
        internal
    {
        transferFrom(owner, address(this), shares);
        epochs[epochId].redeemRequestBalance[receiver] += shares;
        lastRedeemRequestId[owner] = epochId;

        if (
            data.length > 0
                && ERC7540Receiver(receiver).onERC7540RedeemReceived(
                    _msgSender(), owner, epochId, data
                ) != ERC7540Receiver.onERC7540RedeemReceived.selector
        ) {
            revert ReceiverFailed();
        }

        emit DepositRequest(receiver, owner, epochId, _msgSender(), shares);
    }

    function decreaseRedeemRequest(
        uint256 shares,
        address receiver,
        address owner
    )
        external
        whenClosed
        whenNotPaused
    {
        uint256 oldBalance = epochs[epochId].redeemRequestBalance[owner];
        epochs[epochId].redeemRequestBalance[owner] -= shares;
        transfer(receiver, shares);

        emit DecreaseRedeemRequest(
            epochId,
            owner,
            oldBalance,
            epochs[epochId].redeemRequestBalance[owner]
        );
    }

    function pendingRedeemRequest(address owner)
        external
        view
        returns (uint256)
    {
        return epochs[epochId].redeemRequestBalance[owner];
    }

    function claimableRedeemRequest(address owner)
        external
        view
        returns (uint256)
    {
        uint256 lastRequestId = lastRedeemRequestId[owner];
        return isCurrentEpoch(lastRequestId)
            ? 0
            : epochs[lastRequestId].redeemRequestBalance[owner];
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    function previewClaimDeposit(address owner) public view returns (uint256) {
        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        return _convertToShares(assets, lastRequestId, Math.Rounding.Floor);
    }

    function previewClaimRedeem(address owner) public view returns (uint256) {
        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        return _convertToAssets(shares, lastRequestId, Math.Rounding.Floor);
    }

    function claimDeposit(address receiver)
        public
        whenNotPaused
        returns (uint256 shares)
    {
        address owner = _msgSender();
        uint256 lastRequestId = lastDepositRequestId[owner];

        shares = previewClaimDeposit(owner);

        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        epochs[lastRequestId].depositRequestBalance[owner] = 0;

        transfer(receiver, shares);
        emit Withdraw(_msgSender(), receiver, address(this), assets, shares);
        emit Deposit(_msgSender(), owner, assets, shares);
        // emit ClaimDeposit(lastRequestId, _msgSender(), receiver, assets,
        // shares);
    }

    function claimRedeem(address receiver)
        public
        whenNotPaused
        returns (uint256 assets)
    {
        address owner = _msgSender();
        uint256 lastRequestId = lastDepositRequestId[owner];

        assets = previewClaimRedeem(owner);

        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        epochs[lastRequestId].redeemRequestBalance[owner] = 0;

        _ASSET.safeTransfer(receiver, assets);
        emit Deposit(_msgSender(), owner, assets, shares);
        emit Withdraw(_msgSender(), receiver, address(this), assets, shares);
    }

    /*
     * ######################################
     * # GENERAL ERC-4626 RELATED FUNCTIONS #
     * ######################################
    */

    // @return address of the underlying asset.
    function asset() public view returns (address) {
        return address(_ASSET);
    }

    // @dev See {IERC4626-convertToShares}.
    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, epochId, Math.Rounding.Floor);
    }

    function convertToShares(
        uint256 assets,
        uint256 _epochId
    )
        public
        view
        returns (uint256)
    {
        return _convertToShares(assets, _epochId, Math.Rounding.Floor);
    }

    function convertToAssets(
        uint256 shares,
        uint256 _epochId
    )
        public
        view
        returns (uint256)
    {
        return _convertToAssets(shares, _epochId, Math.Rounding.Floor);
    }

    function claimableSharesBalanceInAsset(
        address owner,
        uint256 _epochId
    )
        public
        view
        returns (uint256)
    {
        return convertToAssets(epochs[_epochId].depositRequestBalance[owner]);
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
        return _convertToAssets(shares, epochId, Math.Rounding.Floor);
    }

    /**
     * @dev The `maxDeposit` function is used to calculate the maximum deposit.
     * @notice If the vault is locked or paused, users are not allowed to
     * deposit,
     * the maxDeposit is 0.
     * @return Amount of the maximum underlying assets deposit amount.
     */
    function maxDeposit(address) public view returns (uint256) {
        return isOpen && !paused() ? type(uint256).max : 0;
    }

    /**
     * @dev The `maxMint` function is used to calculate the maximum amount of
     * shares you can mint.
     * @notice If the vault is locked or paused, the maxMint is 0.
     * @return Amount of the maximum shares mintable for the specified address.
     */
    function maxMint(address) public view returns (uint256) {
        return isOpen && !paused() ? type(uint256).max : 0;
    }

    /**
     * @dev See {IERC4626-maxWithdraw}.
     * @notice If the function is called during the lock period the maxWithdraw
     * is `0`.
     * @return Amount of the maximum number of withdrawable underlying assets.
     */
    function maxWithdraw(address owner) public view returns (uint256) {
        return isOpen && !paused()
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
        return isOpen && !paused() ? balanceOf(owner) : 0;
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
     * into the vault. It also checks that the amount of shares minted is
     * greater
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
    )
        public
        returns (uint256)
    {
        uint256 sharesAmount = deposit(assets, receiver);
        if (sharesAmount < minShares) {
            revert ERC4626NotEnoughSharesMinted(
                receiver, sharesAmount, minShares
            );
        }
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
     * @dev The `mintMaxAssets` function is used to mint the specified amount of
     * shares in exchange of the corresponding underlying assets amount from
     * owner. It also checks that the amount of assets deposited is less or
     * equal
     * to the specified maximum amount.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @param maxAssets The maximum amount of assets to be deposited.
     * @return Amount of underlying assets deposited in exchange of the
     * specified
     * amount of shares.
     */
    function mintMaxAssets(
        uint256 shares,
        address receiver,
        uint256 maxAssets
    )
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
    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        uint256 _totalAssets = totalAssets;
        return _totalAssets == 0
            ? assets
            : assets.mulDiv(totalSupply(), _totalAssets, rounding);
    }

    function _convertToShares(
        uint256 assets,
        uint256 requestId,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        uint256 _totalAssets = epochs[requestId].totalAssetsSnapshot;
        return _totalAssets == 0 || requestId == epochId
            ? assets
            : assets.mulDiv(
                epochs[requestId].totalSupplySnapshot, _totalAssets, rounding
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
    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalSupply = totalSupply();
        return totalSupply == 0
            ? shares
            : shares.mulDiv(totalAssets, totalSupply, rounding);
    }

    function _convertToAssets(
        uint256 shares,
        uint256 requestId,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalSupply = epochs[requestId].totalSupplySnapshot;
        return totalSupply == 0 || requestId == epochId
            ? shares
            : shares.mulDiv(
                epochs[requestId].totalAssetsSnapshot, totalSupply, rounding
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
    )
        internal
    {
        // If _ASSET is ERC777, transferFrom can trigger a reentrancy BEFORE the
        // transfer happens through the tokensToSend hook. On the other hand,
        // the tokenReceived hook, that is triggered after the transfer,calls
        // the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any
        // reentrancy would happen before the assets are transferred and before
        // the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        _ASSET.safeTransferFrom(caller, address(this), assets);
        totalAssets += assets;
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
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    )
        internal
    {
        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        _burn(owner, shares);
        totalAssets -= assets;
        _ASSET.safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /*
     * ######################################
     * # AMPHOR SYNTHETIC RELATED FUNCTIONS #
     * ######################################
    */

    /**
     * @dev The `close` function is used to close the vault.
     * It is the only way to lock the vault. It can only be called by the owner
     * of the contract (`onlyOwner` modifier).
     */
    function close() external onlyOwner {
        if (!isOpen) revert VaultIsLocked();

        uint256 _totalAssets = totalAssets;
        if (_totalAssets == 0) revert VaultIsEmpty();

        _ASSET.safeTransfer(owner(), _totalAssets);
        isOpen = false;
        emit EpochStart(block.timestamp, _totalAssets, totalSupply());
    }

    /**
     * @dev The `open` function is used to open the vault.
     * @notice The `end` function is used to end the lock period of the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier)
     * and only when the vault is locked.
     * If there are profits, the performance fees are taken and sent to the
     * owner of the contract.
     * @param assetReturned The underlying assets amount to be deposited into
     * the vault.
     */
    function open(uint256 assetReturned) external onlyOwner whenClosed {
        if (isOpen) revert VaultIsOpen();

        if (
            assetReturned
                < BPS_DIVIDER - _MAX_DRAWDOWN * totalAssets / BPS_DIVIDER
        ) {
            // todo solve this shit

            revert MaxDrawdownReached();
        }

        uint256 pendingDeposit = _ASSET.balanceOf(address(this));
        uint256 fees;

        uint256 _totalAssets = totalAssets;
        if (assetReturned > _totalAssets && feeInBps > 0) {
            uint256 profits;
            unchecked {
                profits = assetReturned - _totalAssets;
            }
            fees = (profits).mulDiv(feeInBps, BPS_DIVIDER, Math.Rounding.Ceil);
        }

        _totalAssets = assetReturned - fees;
        totalAssets = _totalAssets;

        _ASSET.safeTransferFrom(_msgSender(), address(this), _totalAssets);

        emit EpochEnd(
            block.timestamp, _totalAssets, assetReturned, fees, totalSupply()
        );
        isOpen = true;
        _execRequests(pendingDeposit);

        epochId++;
    }

    function _execRequests(uint256 pendingDeposit) internal {
        ////////////////////////////////
        // Pending deposits treatment //
        ////////////////////////////////
        deposit(pendingDeposit, address(this));
        //////////////////////////////
        // Pending redeem treatment //
        //////////////////////////////
        uint256 pendingRedeem = balanceOf(address(this)); // get the shares of

        // the pending withdraws
        redeem(pendingRedeem, address(this), address(this));

        epochs[epochId].totalSupplySnapshot = totalSupply();
        epochs[epochId].totalAssetsSnapshot = totalAssets;
    }

    function restruct(uint256 virtualReturnedAsset) external onlyOwner {
        uint256 _totalAssets = totalAssets;
        emit EpochEnd(
            block.timestamp,
            _totalAssets,
            virtualReturnedAsset,
            0,
            totalSupply()
        );
        emit EpochStart(block.timestamp, _totalAssets, totalSupply());
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
        if (!isOpen) revert VaultIsLocked();
        if (newFee > MAX_FEES) revert FeesTooHigh();
        feeInBps = newFee;
        emit FeesChanged(feeInBps, newFee);
    }

    function setMaxDrawDown(uint16 newMaxDrawDown) external onlyOwner {
        _MAX_DRAWDOWN = newMaxDrawDown;
    }

    /**
     * @dev The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * @notice The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * It can only be called by the owner of the contract (`onlyOwner`
     * modifier).
     * @param token The IERC20 token to be claimed.
     */
    function claimToken(IERC20 token) external onlyOwner {
        if (token != _ASSET) {
            token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
        }
    }

    /*
     * #################################
     * # Pausability RELATED FUNCTIONS #
     * #################################
    */
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
        whenNotPaused
    {
        super._update(from, to, value);
    }

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
        if (_ASSET.allowance(msg.sender, address(this)) < assets) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return deposit(assets, receiver);
    }

    /**
     * @dev The `depositWithPermitMinShares` function is used to deposit
     * underlying assets into the vault using a permit for approval.
     * @param assets The underlying assets amount to be converted into
     * shares.
     * @param receiver The address of the shares receiver.
     * @param minShares The minimum amount of shares to be received in exchange
     * of the specified underlying assets amount.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function depositWithPermitMinShares(
        uint256 assets,
        address receiver,
        uint256 minShares,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < assets) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return depositMinShares(assets, receiver, minShares);
    }

    /**
     * @dev The `mintWithPermit` function is used to mint the specified shares
     * amount in exchange of the corresponding underlying assets amount from
     * `_msgSender()` using a permit for approval.
     * @param shares The amount of shares to be converted into underlying
     * assets.
     * @param receiver The address of the shares receiver.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of underlying assets deposited in exchange of the
     * specified
     * shares amount.
     */
    function mintWithPermit(
        uint256 shares,
        address receiver,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < previewMint(shares)) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return mint(shares, receiver);
    }

    /**
     * @dev The `mintWithPermit` function is used to mint the specified shares
     * amount in exchange of the corresponding underlying assets amount from
     * `_msgSender()` using a permit for approval.
     * @param shares The amount of shares to be converted into underlying
     * assets.
     * @param receiver The address of the shares receiver.
     * @param maxAssets The maximum amount of underlying assets to be deposited
     * in exchange of the specified shares amount.
     * @param permitParams The permit struct containing the permit signature and
     * data.
     * @return Amount of underlying assets deposited in exchange of the
     * specified
     * shares amount.
     */
    function mintWithPermitMaxAssets(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        PermitParams calldata permitParams
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(msg.sender, address(this)) < previewMint(shares)) {
            execPermit(_msgSender(), address(this), permitParams);
        }
        return mintMaxAssets(shares, receiver, maxAssets);
    }

    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data,
        PermitParams calldata permitParams
    )
        external
    {
        if (_ASSET.allowance(owner, address(this)) < assets) {
            execPermit(owner, address(this), permitParams);
        }
        return requestDeposit(assets, receiver, owner, data);
    }

    function execPermit(
        address owner,
        address spender,
        PermitParams calldata permitParams
    )
        internal
    {
        ERC20Permit(address(_ASSET)).permit(
            owner,
            spender,
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s
        );
    }

    /*
     * #################################
     * #  Permit 2 RELATED FUNCTIONS   #
     * #################################
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
    )
        external
    {
        if (_ASSET.allowance(owner, address(this)) < assets) {
            execPermit2(permit2Params);
        }
        return requestDeposit(assets, receiver, owner, data);
    }

    function depositWithPermit2(
        uint256 assets,
        address receiver,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < assets) {
            execPermit2(permit2Params);
        }
        return deposit(assets, receiver);
    }

    function depositWithPermit2MinShares(
        uint256 assets,
        address receiver,
        uint256 minShares,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < assets) {
            execPermit2(permit2Params);
        }
        return depositMinShares(assets, receiver, minShares);
    }

    function mintWithPermit2(
        uint256 shares,
        address receiver,
        Permit2Params calldata permit2Params
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < previewMint(shares))
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
    )
        external
        returns (uint256)
    {
        if (_ASSET.allowance(_msgSender(), address(this)) < previewMint(shares))
        {
            execPermit2(permit2Params);
        }
        return mintMaxAssets(shares, receiver, maxAssets);
    }
}
