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
    PermitParams,
    IERC4626
} from "./SyncSynthVault.sol";

import { SyncSynthVault } from "./SyncSynthVault.sol";

import "forge-std/console.sol"; //todo remove

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
    uint256 totalSupplySnapshotForRedeem;
    uint256 totalAssetsSnapshotForRedeem;
    uint256 totalSupplySnapshotForDeposit;
    uint256 totalAssetsSnapshotForDeposit;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

uint256 constant BPS_DIVIDER = 10_000;
uint16 constant MAX_FEES = 3000; // 30%

contract Silo {
    constructor(IERC20 underlying) {
        underlying.forceApprove(msg.sender, type(uint256).max);
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
    Silo public pendingSilo;
    Silo public claimableSilo;
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

    event AsyncWithdraw(
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
        address indexed owner,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    event ClaimRedeem(
        uint256 indexed requestId,
        address indexed owner,
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
    error MustClaimFirst(address owner);

    error ReceiverFailed();
    error NotOwner();
    error NullRequest();
    error ERC7540CantRequestDepositOnBehalfOf();
    /*
     * ##############################
     * # AMPHOR SYNTHETIC FUNCTIONS #
     * ##############################
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAllowanceTransfer _permit2) SyncSynthVault(_permit2) {
        // _disableInitializers(); // TODO uncomment after
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
        override
        initializer
    {
        super.initialize(fees, owner, underlying, name, symbol);
        epochId = 1;
        pendingSilo = new Silo(underlying);
        claimableSilo = new Silo(underlying);
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
        whenNotPaused
        whenClosed
    {
        // vault
        if (_msgSender() != owner) {
            revert ERC7540CantRequestDepositOnBehalfOf();
        }
        if (previewClaimDeposit(receiver) > 0) {
            revert MustClaimFirst(receiver);
        }

        if (assets > maxDepositRequest(owner)) {
            revert ExceededMaxDepositRequest(
                receiver, assets, maxDepositRequest(owner)
            );
        }

        // if _msgSender
        _asset.safeTransferFrom(owner, address(pendingSilo), assets);

        _createDepositRequest(assets, receiver, owner, data);
    }

    // transfer must happen before this function is called
    function _createDepositRequest(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    )
        internal
    {
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

    function totalPendingDeposits() external view returns (uint256) {
        return vaultIsOpen ? 0 : _asset.balanceOf(address(pendingSilo));
    }

    function totalPendingRedeems() external view returns (uint256) {
        return vaultIsOpen ? 0 : balanceOf(address(pendingSilo));
    }

    function totalClaimableShares() external view returns (uint256) {
        return balanceOf(address(claimableSilo));
    }

    function totalClaimableAssets() external view returns (uint256) {
        return _asset.balanceOf(address(claimableSilo));
    }

    function maxDepositRequest(address) public view returns (uint256) {
        // todo maybe use previewClaimDeposit instead or claimableDepositRequest
        return vaultIsOpen || paused() ? 0 : type(uint256).max;
    }

    function maxRedeemRequest(address owner) public view returns (uint256) {
        // todo maybe use previewClaimRedeem instead or claimableRedeemRequest
        return vaultIsOpen || paused() ? 0 : balanceOf(owner);
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
        _asset.safeTransferFrom(address(pendingSilo), receiver, assets);

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
        whenNotPaused
        whenClosed
    {
        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), shares);
        }
        if (previewClaimRedeem(receiver) > 0) {
            revert MustClaimFirst(receiver);
        }
        if (shares > maxRedeemRequest(owner)) {
            revert ExceededMaxRedeemRequest(
                receiver, shares, maxRedeemRequest(owner)
            );
        }

        _update(owner, address(pendingSilo), shares);
        console.log("shares to redeem", shares);
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
        uint256 lastRequestId = lastRedeemRequestId[owner];
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
        shares = previewClaimDeposit(owner);
        // _convertToShares

        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        epochs[lastRequestId].depositRequestBalance[owner] = 0;
        _update(address(claimableSilo), receiver, shares);
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
        internal
        whenNotPaused
        returns (uint256 assets)
    {
        assets = previewClaimRedeem(owner);
        // 26000
        // 25999
        uint256 lastRequestId = lastRedeemRequestId[owner];
        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        epochs[lastRequestId].redeemRequestBalance[owner] = 0;
        _asset.safeTransferFrom(address(claimableSilo), address(this), assets);
        _asset.transfer(receiver, assets);
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
        if (isCurrentEpoch(requestId)) {
            return 0;
        }
        uint256 totalAssets =
            epochs[requestId].totalAssetsSnapshotForDeposit + 1;
        uint256 totalSupply = epochs[requestId].totalSupplySnapshotForDeposit
            + 10 ** decimalsOffset;

        return assets.mulDiv(totalSupply, totalAssets, rounding);
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
        if (isCurrentEpoch(requestId)) {
            return 0;
        }
        uint256 totalAssets = epochs[requestId].totalAssetsSnapshotForRedeem + 1;
        uint256 totalSupply = epochs[requestId].totalSupplySnapshotForRedeem
            + 10 ** decimalsOffset;

        return shares.mulDiv(totalAssets, totalSupply, rounding);
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
        if (!vaultIsOpen) revert VaultIsClosed();

        if (totalAssets() == 0) revert VaultIsEmpty();

        lastSavedBalance = totalAssets();
        _asset.safeTransfer(owner(), lastSavedBalance);
        vaultIsOpen = false;
        emit EpochStart(block.timestamp, lastSavedBalance, totalSupply());
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
        _open(assetReturned);
        _execRequests();
        epochId++;
    }

    function _checkMaxDrawdown(
        uint256 _lastSavedBalance,
        uint256 newSavedBalance
    )
        internal
        view
    {
        if (
            newSavedBalance
                < _lastSavedBalance.mulDiv(
                    BPS_DIVIDER - _maxDrawdown, BPS_DIVIDER, Math.Rounding.Ceil
                )
        ) revert MaxDrawdownReached();
    }

    function _computeFees(
        uint256 _lastSavedBalance,
        uint256 newSavedBalance
    )
        internal
        view
        returns (uint256 fees)
    {
        if (newSavedBalance > _lastSavedBalance && feesInBps > 0) {
            uint256 profits;
            unchecked {
                profits = newSavedBalance - _lastSavedBalance;
            }
            fees = (profits).mulDiv(feesInBps, BPS_DIVIDER, Math.Rounding.Ceil);
        }
    }

    function settle(uint256 newSavedBalance)
        external
        onlyOwner
        whenNotPaused
        whenClosed
    {
        address _owner = owner();
        // calculate the fees between lastSavedBalance and newSavedBalance
        uint256 _lastSavedBalance = lastSavedBalance;
        _checkMaxDrawdown(_lastSavedBalance, newSavedBalance);

        // taking fees if positive yield
        uint256 fees = _computeFees(_lastSavedBalance, newSavedBalance);

        emit EpochEnd(
            block.timestamp,
            _lastSavedBalance,
            newSavedBalance,
            fees,
            totalSupply()
        );

        _lastSavedBalance = newSavedBalance - fees;
        // if withdraw is higher than deposit -> transfer from owner the diff &&
        // update lastSavedBalance = newSavedBalance - diff
        // do the settlement of the requests
        // if deposit is higher than withdraw -> transfer to owner the diff &&
        // update lastSavedBalance = newSavedBalance + diff
        // IERC20()
        uint256 _pendingRedeem = balanceOf(address(pendingSilo));
        uint256 assetsToWithdraw = previewRedeem(_pendingRedeem);
        uint256 _pendingDeposit = _asset.balanceOf(address(pendingSilo));
        uint256 sharesToMint = previewDeposit(_pendingDeposit);

        // Settle the shares balance
        _burn(address(pendingSilo), _pendingRedeem);
        _mint(address(claimableSilo), sharesToMint);

        // Settle assets balance
        // either there are more deposits than withdrawals
        if (_pendingDeposit > assetsToWithdraw) {
            _asset.safeTransferFrom(
                address(pendingSilo), _owner, _pendingDeposit - assetsToWithdraw
            );
            _asset.safeTransferFrom(
                address(pendingSilo), address(claimableSilo), assetsToWithdraw
            );
        } else {
            _asset.safeTransferFrom(
                _owner,
                address(claimableSilo),
                assetsToWithdraw - _pendingDeposit
            );
            _asset.safeTransferFrom(
                address(pendingSilo), address(claimableSilo), _pendingDeposit
            );
        }

        // emit deposit + async deposit + withdraw + async withdraw
        emit Deposit(_owner, _owner, _pendingDeposit, sharesToMint);
        emit AsyncDeposit(epochId, _pendingDeposit, _pendingDeposit);
        emit Withdraw(_owner, _owner, _owner, assetsToWithdraw, _pendingRedeem);
        emit AsyncWithdraw(epochId, _pendingRedeem, _pendingRedeem);

        // epochs[epochId].totalSupplySnapshot = totalSupply();
        // epochs[epochId].totalAssetsSnapshot =
        // lastSavedBalance + _pendingDeposit - assetsToWithdraw;

        // if withdraw is higher than deposit -> transfer from owner the diff &&
        // update lastSavedBalance = newSavedBalance - diff
        // do the settlement of the requests
        epochId++;
    }

    /**
     * @dev The `open` function is used to open the vault.
     * @notice The `end` function is used to end the lock period of the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier)
     * and only when the vault is locked.
     * If there are profits, the performance fees are taken and sent to the
     * owner of the contract.
     * @param returnedAssets The underlying assets amount to be deposited into
     * the vault.
     */
    function _open(uint256 returnedAssets) internal {
        // check for maxf drawdown
        uint256 _lastSavedBalance = lastSavedBalance;
        _checkMaxDrawdown(_lastSavedBalance, returnedAssets);

        // taking fees if positive yield
        uint256 fees = _computeFees(_lastSavedBalance, returnedAssets);

        _asset.safeTransferFrom(
            _msgSender(), address(this), returnedAssets - fees
        );

        emit EpochEnd(
            block.timestamp,
            _lastSavedBalance,
            returnedAssets,
            fees,
            totalSupply()
        );
        lastSavedBalance = 0;
        vaultIsOpen = true;
    }

    function _execRequests() internal {
        ////////////////////////////////
        // Pending deposits treatment //
        ////////////////////////////////

        uint256 _pendingDeposit = _asset.balanceOf(address(pendingSilo));
        epochs[epochId].totalSupplySnapshotForDeposit = totalSupply();
        epochs[epochId].totalAssetsSnapshotForDeposit = totalAssets();
        uint256 sharesToMint = previewDeposit(_pendingDeposit);
        _deposit(
            address(pendingSilo),
            address(claimableSilo),
            _pendingDeposit,
            sharesToMint
        );
        emit AsyncDeposit(epochId, _pendingDeposit, _pendingDeposit);

        //////////////////////////////
        // Pending redeem treatment //
        //////////////////////////////
        uint256 _pendingRedeem = balanceOf(address(pendingSilo));

        uint256 assetsToWithdraw = previewRedeem(_pendingRedeem); // 10 & 11
        epochs[epochId].totalSupplySnapshotForRedeem = totalSupply();
        epochs[epochId].totalAssetsSnapshotForRedeem = totalAssets();
        console.log("pendingRedeem is ", _pendingRedeem);
        console.log("assetsToWithdraw", assetsToWithdraw);
        _withdraw(
            address(pendingSilo), // to avoid a spending allowance
            address(claimableSilo),
            address(pendingSilo),
            assetsToWithdraw,
            _pendingRedeem
        );
        // 9 & 10
        emit AsyncWithdraw(epochId, _pendingRedeem, _pendingRedeem);
        console.log(
            "previewRedeem after withdraw", previewRedeem(_pendingRedeem)
        );

        console.log("total supply snapshot", totalSupply());
        console.log("total assets snapshot", totalAssets());
    }

    /*
     * #################################
     * #   Permit RELATED FUNCTIONS    #
     * #################################
    */

    function claimAndRequestDepositWithPermit(
        uint256 assets,
        address receiver,
        bytes memory data,
        PermitParams calldata permitParams
    )
        external
    {
        _claimDeposit(receiver, receiver);
        requestDepositWithPermit(assets, receiver, data, permitParams);
    }

    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        bytes memory data,
        PermitParams calldata permitParams
    )
        public
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
        uint160 assets,
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
        PERMIT2.transferFrom(owner, address(this), assets, address(_asset));

        _createDepositRequest(assets, receiver, owner, data);
    }
}
