//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC7540, IERC165, IERC7540Redeem } from "./interfaces/IERC7540.sol";
import { ERC7540Receiver } from "./interfaces/ERC7540Receiver.sol";
import {
    IERC20,
    SafeERC20,
    IAllowanceTransfer,
    ERC20Upgradeable,
    Math,
    PermitParams
} from "./SyncSynthVault.sol";

import { SyncSynthVault } from "./SyncSynthVault.sol";

// import "forge-std/console.sol"; //todo remove

/**
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
 *         @@@@@@@@@@@@@@@@@@*   ASync   *@@@@@@@@@@@@@@@@@@@
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

struct EpochData {
    uint256 totalSupplySnapshot;
    uint256 totalAssetsSnapshot;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

uint256 constant BPS_DIVIDER = 10_000;
uint16 constant MAX_FEES = 3000; // 30%

contract LiquidityContainer {
    constructor () {
        IERC20(AsyncSynthVault(msg.sender).asset()).approve(msg.sender, type(uint256).max);
    }
}

contract AsyncSynthVault is IERC7540, SyncSynthVault {
    /*
     * ####################################
     * # AMPHOR SYNTHETIC RELATED STORAGE #
     * ####################################
    */

    // @return Amount of the perf fees applied on the positive yield.
    uint256 public epochId;
    LiquidityContainer public liquidityContainer;
    mapping(uint256 epochId => EpochData epoch) public epochs;
    mapping(address user => uint256 epochId) public lastDepositRequestId;
    mapping(address user => uint256 epochId) public lastRedeemRequestId;

    /*
     * ##########
     * # EVENTS #
     * ##########
    */

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

    /*
     * ##########
     * # ERRORS #
     * ##########
     */
    error ExceededMaxRedeemRequest(
        address receiver, uint256 shares, uint256 maxShares
    );
    error ExceededMaxDepositRequest(
        address receiver, uint256 assets, uint256 maxDeposit
    );
    error ReceiverFailed();

    /*
     * ##############################
     * # AMPHOR SYNTHETIC FUNCTIONS #
     * ##############################
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAllowanceTransfer _permit2) SyncSynthVault(_permit2) {
        _disableInitializers();
    }

    function initialize(
        uint16 fees,
        address owner,
        IERC20 underlying,
        string memory name,
        string memory symbol
    )
        public
        override
        initializer
    {
        super.initialize(fees, owner, underlying, name, symbol);
        epochId = 1;
        liquidityContainer = new LiquidityContainer();
        _asset.forceApprove(address(this), type(uint256).max); // allowing futur
            // deposits into own vault
        approve(address(this), type(uint256).max); // allowing futur redeem into
            // own vault
    }

    function isCurrentEpoch(uint256 requestId) internal view returns (bool) {
        return requestId == epochId;
    }

    function requestDeposit(
        uint256 assets,
        address receiver,
        address owner, // this should not be here
        bytes memory data
    )
        public
        whenClosed
        whenNotPaused
    {
        if (_msgSender() != owner) {
            revert(); //todo add error
        }
        if (assets == 0) {
            revert(); //todo add error
        }
        if (assets > maxDepositRequest(receiver)) {
            revert ExceededMaxDepositRequest(
                receiver, assets, maxDepositRequest(receiver)
            );
        }

        _asset.safeTransferFrom(owner, address(liquidityContainer), assets);

        _createDepositRequest(assets, receiver, owner, data);
    }

    // transfer must happen before this function is called TODO maybe change
    // this
    function _createDepositRequest(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    )
        internal
    {
        epochs[epochId].depositRequestBalance[receiver] += assets;
        // epochs[lastDepositRequestId[owner]].depositRequestBalance[owner];
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
        return isOpen ? 0 : _asset.balanceOf(address(this));
    }

    // tree done
    function totalPendingRedeems() public view returns (uint256) {
        return isOpen ? 0 : balanceOf(address(this));
    }

    // tree todo
    function maxDepositRequest(address receiver)
        public
        view
        returns (uint256)
    {
        // todo maybe use previewClaimDeposit instead or claimableDepositRequest
        uint256 lastRequestId = lastDepositRequestId[receiver];
        uint256 lastRequestBalance =
            epochs[lastRequestId].depositRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochId;

        return isOpen || paused() || hasClaimableRequest ? 0 : type(uint256).max;
    }

    // tree todo
    function maxRedeemRequest(address owner) public view returns (uint256) {
        // todo maybe use previewClaimRedeem instead or claimableRedeemRequest
        uint256 lastRequestId = lastRedeemRequestId[owner];
        uint256 lastRequestBalance =
            epochs[lastRequestId].redeemRequestBalance[owner];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochId;

        return isOpen || paused() || hasClaimableRequest ? 0 : balanceOf(owner);
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
        _claimDeposit(receiver, receiver);
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
        _claimRedeem(receiver, receiver);
        requestRedeem(shares, receiver, owner, data);
    }

    // tree done
    function decreaseDepositRequest(
        uint256 assets,
        address receiver
    )
        external
        whenClosed
        whenNotPaused
    {
        address owner = _msgSender();
        uint256 oldBalance = epochs[epochId].depositRequestBalance[owner];
        epochs[epochId].depositRequestBalance[owner] -= assets;
        _asset.safeTransfer(receiver, assets);

        emit DecreaseDepositRequest(
            epochId,
            owner,
            oldBalance,
            epochs[epochId].depositRequestBalance[owner]
        );
    }

    // tree done
    function pendingDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        return epochs[epochId].depositRequestBalance[owner];
    }

    // tree done
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

    // tree done
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
        if (shares > maxRedeemRequest(receiver)) {
            revert ExceededMaxRedeemRequest(
                receiver, shares, maxRedeemRequest(receiver)
            );
        }
        if (shares == 0) {
            revert(); //todo add error
        }

        _update(owner, address(liquidityContainer), shares);

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
        epochs[epochId].redeemRequestBalance[receiver] += shares;
        lastRedeemRequestId[owner] = epochId;

        if (
            data.length > 0
                && ERC7540Receiver(receiver).onERC7540RedeemReceived(
                    _msgSender(), owner, epochId, data
                ) != ERC7540Receiver.onERC7540RedeemReceived.selector
        ) revert ReceiverFailed();

        emit RedeemRequest(receiver, owner, epochId, _msgSender(), shares);
    }

    function decreaseRedeemRequest(
        uint256 shares,
        address receiver
    )
        external
        whenClosed
        whenNotPaused
    {
        address owner = _msgSender();
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
        return _claimDeposit(_msgSender(), receiver);
    }

    function _claimDeposit(
        address owner,
        address receiver
    )
        internal
        returns (uint256 shares)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];

        shares = previewClaimDeposit(owner);

        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        epochs[lastRequestId].depositRequestBalance[owner] = 0;

        transfer(receiver, shares);

        emit ClaimDeposit(lastRequestId, owner, receiver, assets, shares);
    }

    function claimRedeem(address receiver)
        public
        whenNotPaused
        returns (uint256 assets)
    {
        return _claimRedeem(_msgSender(), receiver);
    }

    function _claimRedeem(
        address owner,
        address receiver
    )
        public
        whenNotPaused
        returns (uint256 assets)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];

        assets = previewClaimRedeem(owner);

        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        epochs[lastRequestId].redeemRequestBalance[owner] = 0;

        _asset.safeTransfer(receiver, assets);
        emit ClaimRedeem(lastRequestId, owner, receiver, assets, shares);
    }

    /*
     * ######################################
     * # GENERAL ERC-7540 RELATED FUNCTIONS #
     * ######################################
    */

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

    function claimableDepositBalanceInAsset(address owner)
        public
        view
        returns (uint256)
    {
        uint256 shares = previewClaimDeposit(owner);
        return convertToAssets(shares);
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
    function close() external override onlyOwner {
        if (!isOpen) revert VaultIsLocked();

        uint256 _totalAssets = totalAssets;
        if (_totalAssets == 0) revert VaultIsEmpty();

        _asset.safeTransfer(owner(), _totalAssets);
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
    function open(uint256 assetReturned)
        external
        override
        onlyOwner
        whenClosed
    {
        uint256 pendingDeposit = _asset.balanceOf(address(liquidityContainer));
        _open(assetReturned);
        _execRequests(pendingDeposit);
        epochId++;
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
    function _open(uint256 assetReturned) internal {
        if (
            assetReturned
                < totalAssets.mulDiv(
                    BPS_DIVIDER - _maxDrawdown, BPS_DIVIDER, Math.Rounding.Ceil
                )
        ) revert MaxDrawdownReached();

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

        _asset.safeTransferFrom(_msgSender(), address(this), _totalAssets);

        emit EpochEnd(
            block.timestamp, _totalAssets, assetReturned, fees, totalSupply()
        );
        isOpen = true;
    }

    function _execRequests(uint256 pendingDeposit) internal {
        ////////////////////////////////
        // Pending deposits treatment //
        ////////////////////////////////

        uint256 sharesToMint = previewDeposit(pendingDeposit);
        _deposit(
            address(liquidityContainer),
            address(this),
            pendingDeposit,
            sharesToMint
        );

        //////////////////////////////
        // Pending redeem treatment //
        //////////////////////////////
        uint256 pendingRedeem = balanceOf(address(liquidityContainer));
        uint256 assetsToRedeem = previewRedeem(pendingRedeem);
        _withdraw(
            address(this),
            address(liquidityContainer),
            assetsToRedeem,
            pendingRedeem
        );

        epochs[epochId].totalSupplySnapshot = totalSupply();
        epochs[epochId].totalAssetsSnapshot = totalAssets;
        emit AsyncDeposit(epochId, pendingDeposit, pendingDeposit);
        emit AsyncRedeem(epochId, pendingRedeem, pendingRedeem);
    }

    /*
     * #################################
     * #   Permit RELATED FUNCTIONS    #
     * #################################
    */

    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        bytes memory data,
        PermitParams calldata permitParams
    )
        external
    {
        address owner = _msgSender();
        if (_asset.allowance(owner, address(this)) < assets) {
            execPermit(owner, address(this), permitParams);
        }
        return requestDeposit(assets, receiver, owner, data);
    }

    /*
     * #################################
     * #  Permit 2 RELATED FUNCTIONS   #
     * #################################
    */

    function requestDepositWithPermit2(
        uint256 assets,
        address receiver,
        bytes memory data,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    )
        external
        whenClosed
        whenNotPaused
    {
        address owner = _msgSender();
        execPermit2(permitSingle, signature);
        PERMIT2.transferFrom(
            owner, address(this), uint160(assets), address(_asset)
        );

        _createDepositRequest(assets, receiver, owner, data);
    }
}
