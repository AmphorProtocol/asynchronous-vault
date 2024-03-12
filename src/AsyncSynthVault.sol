//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    IERC7540,
    IERC165,
    IERC7540Redeem,
    IERC7540Deposit
} from "./interfaces/IERC7540.sol";
import { ERC7540Receiver } from "./interfaces/ERC7540Receiver.sol";
import { IERC20, SafeERC20, Math, PermitParams } from "./SyncSynthVault.sol";

import { SyncSynthVault } from "./SyncSynthVault.sol";

/**
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

/*
    This structure contains all the informations needed to let user claim their
    request after we processed those. To avoid rounding errors we store the
totalSupply and totalAssets at the time of the deposit/redeem for the deposit
and
    the redeem. We also store the amount of assets and shares given by the user.*/
struct EpochData {
    uint256 totalSupplySnapshotForRedeem;
    uint256 totalAssetsSnapshotForRedeem;
    uint256 totalSupplySnapshotForDeposit;
    uint256 totalAssetsSnapshotForDeposit;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

struct SettleValues {
    uint256 lastSavedBalance;
    uint256 fees;
    uint256 pendingRedeem;
    uint256 sharesToMint;
    uint256 pendingDeposit;
    uint256 assetsToWithdraw;
    uint256 totalAssetsSnapshotForDeposit;
    uint256 totalSupplySnapshotForDeposit;
    uint256 totalAssetsSnapshotForRedeem;
    uint256 totalSupplySnapshotForRedeem;
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
    Silo public pendingSilo; // to manage the pending deposits and redeems we
        // store them in a contract whose function is to hold the assets/shares.
    Silo public claimableSilo; // to manage the claimable deposits and redeems
        // we
        // store them in a contract whose function is to hold the assets/shares.
    mapping(uint256 epochId => EpochData epoch) public epochs;
    mapping(address user => uint256 epochId) public lastDepositRequestId;
    mapping(address user => uint256 epochId) public lastRedeemRequestId;

    /*
     * ##########
     * # EVENTS #
     * ##########
    */

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
    constructor() SyncSynthVault() {
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
        override
        initializer
    {
        super.initialize(fees, owner, underlying, name, symbol);
        epochId = 1;
        pendingSilo = new Silo(underlying);
        claimableSilo = new Silo(underlying);
    }

    /*
    Since we only allow one claimable request at a time, users must claim
        their request before making a new one. This function let users claim
        and request a deposit in one transaction.
    */
    function claimAndRequestDeposit(
        uint256 assets,
        address receiver,
        bytes memory data
    )
        external
    {
        _claimDeposit(receiver, receiver);
        requestDeposit(assets, receiver, _msgSender(), data);
    }

    /*
        Same logic as `claimAndRequestDeposit` but for redeem requests.
    */
    function claimAndRequestRedeem(
        uint256 shares,
        bytes memory data
    )
        external
    {
        address owner = _msgSender();
        _claimRedeem(owner, owner);
        requestRedeem(shares, owner, owner, data);
    }

    /*
    This function is used to decrease the amount of assets requested to deposit
    by the
        user. It can only be called by the user who made the request.
    */
    function decreaseDepositRequest(uint256 assets)
        external
        whenClosed
        whenNotPaused
    {
        address owner = _msgSender();
        uint256 oldBalance = epochs[epochId].depositRequestBalance[owner];
        epochs[epochId].depositRequestBalance[owner] -= assets;
        _asset.safeTransferFrom(address(pendingSilo), owner, assets);

        emit DecreaseDepositRequest(
            epochId,
            owner,
            oldBalance,
            epochs[epochId].depositRequestBalance[owner]
        );
    }

    /*
    This function is used to decrease the amount of shares requested to redeem
    by the
        user. It can only be called by the user who made the request.
    */
    function decreaseRedeemRequest(uint256 shares)
        external
        whenClosed
        whenNotPaused
    {
        address owner = _msgSender();
        uint256 oldBalance = epochs[epochId].redeemRequestBalance[owner];
        epochs[epochId].redeemRequestBalance[owner] -= shares;
        _update(address(pendingSilo), owner, shares);

        emit DecreaseRedeemRequest(
            epochId,
            owner,
            oldBalance,
            epochs[epochId].redeemRequestBalance[owner]
        );
    }

    /*
     * ######################################
     * # AMPHOR SYNTHETIC RELATED FUNCTIONS #
     * ######################################
    */

    /**
     * @dev The `close` function is used to close the vault.
     * It can only be called by the owner of the contract (`onlyOwner`
     * modifier).
     */
    function close() external override onlyOwner {
        if (!vaultIsOpen) revert VaultIsClosed();

        if (totalAssets() == 0) revert VaultIsEmpty();

        lastSavedBalance = totalAssets();
        vaultIsOpen = false;
        _asset.safeTransfer(owner(), lastSavedBalance);
        emit EpochStart(block.timestamp, lastSavedBalance, totalSupply());
    }

    /**
     * @dev The `open` function is used to open the vault.
     * @notice The `open` function is used to end the lock period of the vault.
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
        whenNotPaused
        whenClosed
    {
        (uint256 newBalance,) = _settle(assetReturned);
        vaultIsOpen = true;
        _asset.safeTransferFrom(owner(), address(this), newBalance);
    }

    /*
     * #################################
     * #   Permit RELATED FUNCTIONS    #
     * #################################
    */

    /* This function is used to claim the pending deposit and request a new one
    in one transaction using permit signatures */
    function claimAndRequestDepositWithPermit(
        uint256 assets,
        bytes memory data,
        PermitParams calldata permitParams
    )
        external
    {
        address msgSender = _msgSender();
        _claimDeposit(msgSender, msgSender);
        requestDepositWithPermit(assets, msgSender, data, permitParams);
    }

    /*
    Since amphor strategies can be time sensitive, we must be able to switch
    epoch without needing
    to put all the funds back. Using _settle we can virtually put back the
    funds, check how much we owe
    to users that want to redeem and maybe take the extra funds from the deposit
    requests.
    
    */
    function settle(uint256 newSavedBalance) external {
        (uint256 lastSavedBalance, uint256 totalSupply) =
            _settle(newSavedBalance);
        lastSavedBalance = 0;
        emit EpochStart(block.timestamp, lastSavedBalance, totalSupply);
    }

    /**
     * @dev How many shares a users currently has waiting to be redeem.
     *
     */
    function pendingRedeemRequest(address owner)
        external
        view
        returns (uint256)
    {
        return epochs[epochId].redeemRequestBalance[owner];
    }

    /**
     * @dev How many shares are  virtually waiting for the user to be redeemed
     * via
     * the `claimRedeem` function.
     */
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

    /**
     * @dev How many assets are currently waiting to be deposited for the user.
     */
    function pendingDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        return epochs[epochId].depositRequestBalance[owner];
    }

    /**
     * @dev How many assets are virtually waiting for the user to be deposit
     * via the `claimDeposit` function.
     */
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

    /**
     * @dev How many assets are currently waiting to be deposited for all users.
     */
    function totalPendingDeposits() external view returns (uint256) {
        return vaultIsOpen ? 0 : _asset.balanceOf(address(pendingSilo));
    }

    /**
     * @dev How many shares are  waiting to be redeemed for all users.
     */
    function totalPendingRedeems() external view returns (uint256) {
        return vaultIsOpen ? 0 : balanceOf(address(pendingSilo));
    }

    function totalClaimableShares() external view returns (uint256) {
        return balanceOf(address(claimableSilo));
    }

    function totalClaimableAssets() external view returns (uint256) {
        return _asset.balanceOf(address(claimableSilo));
    }

    /**
     * @dev when the vault is closed, users can only request to deposit.
     * By doing this funds will be sent and wait in the pendingSilo.
     * When the owner will call the `open` or `settle` function, the funds will
     * be
     * deposited and the minted shares will be sent to the claimableSilo. Waiting
     * for the users to claim them.
     */
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

        _asset.safeTransferFrom(owner, address(pendingSilo), assets);

        _createDepositRequest(assets, receiver, owner, data);
    }

    /**
     * @dev when the vault is closed, users can only request to redeem.
     * By doing this shares will be sent and wait in the pendingSilo.
     * When the owner will call the `open` or `settle` function, the shares will
     * be
     * redeemed and the assets will be sent to the claimableSilo. Waiting for
     * the
     * users to claim them.
     */
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
        // Create a new request
        _createRedeemRequest(shares, receiver, owner, data);
    }

    /**
     * @dev This function let users claim the shares we owe them after we
     * processed their deposit request, in the _settle function.
     */
    function claimDeposit(address receiver)
        public
        whenNotPaused
        returns (uint256 shares)
    {
        return _claimDeposit(_msgSender(), receiver);
    }

    /**
     *
     * @dev This function let users claim the assets we owe them after we
     * processed their redeem request, in the _settle function.
     */
    function claimRedeem(address receiver)
        public
        whenNotPaused
        returns (uint256 assets)
    {
        return _claimRedeem(_msgSender(), receiver);
    }

    /**
     * @dev This funciton let user request a deposit using permit signatures.
     */
    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        bytes memory data,
        PermitParams calldata permitParams
    )
        public
    {
        address msgSender = _msgSender();
        if (_asset.allowance(msgSender, address(this)) < assets) {
            execPermit(msgSender, address(this), permitParams);
        }
        return requestDeposit(assets, receiver, msgSender, data);
    }

    /**
     * @dev users can request deposit only when the vault is closed and not
     * paused.
     */
    function maxDepositRequest(address) public view returns (uint256) {
        return vaultIsOpen || paused() ? 0 : type(uint256).max;
    }

    /**
     * @dev users can request redeem only when the vault is closed and not
     * paused.
     */
    function maxRedeemRequest(address owner) public view returns (uint256) {
        return vaultIsOpen || paused() ? 0 : balanceOf(owner);
    }

    /**
     * @dev This function let users preview how many shares they will get if
     * they claim their deposit request.
     */
    function previewClaimDeposit(address owner) public view returns (uint256) {
        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        return _convertToShares(assets, lastRequestId, Math.Rounding.Floor);
    }

    /**
     * @dev This function let users preview how many assets they will get if
     * they claim their redeem request.
     */
    function previewClaimRedeem(address owner) public view returns (uint256) {
        uint256 lastRequestId = lastRedeemRequestId[owner];
        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        return _convertToAssets(shares, lastRequestId, Math.Rounding.Floor);
    }

    /**
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

    /**
     *
     * Utils function to convert the shares claimable into assets. It can
     * be used in the front end to save an rpc call.
     */
    function claimableDepositBalanceInAsset(address owner)
        public
        view
        returns (uint256)
    {
        uint256 shares = previewClaimDeposit(owner);
        return convertToAssets(shares);
    }

    /**
     * Using this the owner can know if he will have to send money to the
     * claimableSilo (for users who want to leave the vault) or if he will
     * receive money from it.
     */
    function previewSettle(uint256 newSavedBalance)
        public
        view
        returns (
            uint256 assetsToOwner,
            uint256 assetsToVault,
            SettleValues memory settleValues
        )
    {
        uint256 _lastSavedBalance = lastSavedBalance;
        _checkMaxDrawdown(_lastSavedBalance, newSavedBalance);

        // calculate the fees between lastSavedBalance and newSavedBalance
        uint256 fees = _computeFees(_lastSavedBalance, newSavedBalance);
        uint256 totalSupply = totalSupply();

        // taking fees if positive yield
        _lastSavedBalance = newSavedBalance - fees;

        address pendingSiloAddr = address(pendingSilo);
        uint256 pendingRedeem = balanceOf(pendingSiloAddr);
        uint256 pendingDeposit = _asset.balanceOf(pendingSiloAddr);

        uint256 sharesToMint = pendingDeposit.mulDiv(
            totalSupply + 1, _lastSavedBalance + 1, Math.Rounding.Floor
        );

        uint256 totalAssetsSnapshotForDeposit = _lastSavedBalance + 1;
        uint256 totalSupplySnapshotForDeposit = totalSupply + 1;

        uint256 assetsToWithdraw = pendingRedeem.mulDiv(
            _lastSavedBalance + pendingDeposit + 1,
            totalSupply + sharesToMint + 1,
            Math.Rounding.Floor
        );

        uint256 totalAssetsSnapshotForRedeem =
            _lastSavedBalance + pendingDeposit + 1;
        uint256 totalSupplySnapshotForRedeem = totalSupply + sharesToMint + 1;

        settleValues = SettleValues({
            lastSavedBalance: _lastSavedBalance + fees,
            fees: fees,
            pendingRedeem: pendingRedeem,
            sharesToMint: sharesToMint,
            pendingDeposit: pendingDeposit,
            assetsToWithdraw: assetsToWithdraw,
            totalAssetsSnapshotForDeposit: totalAssetsSnapshotForDeposit,
            totalSupplySnapshotForDeposit: totalSupplySnapshotForDeposit,
            totalAssetsSnapshotForRedeem: totalAssetsSnapshotForRedeem,
            totalSupplySnapshotForRedeem: totalSupplySnapshotForRedeem
        });

        if (pendingDeposit > assetsToWithdraw) {
            assetsToOwner = pendingDeposit - assetsToWithdraw;
        } else if (pendingDeposit < assetsToWithdraw) {
            assetsToVault = assetsToWithdraw - pendingDeposit;
        }
    }

    /**
     * @dev see EIP
     * @param interfaceId The interface id to check for.
     * @return True if the contract implements the interface.
     */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7540Redeem).interfaceId
            || interfaceId == type(IERC7540Deposit).interfaceId;
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

    function _claimDeposit(
        address owner,
        address receiver
    )
        internal
        returns (uint256 shares)
    {
        shares = previewClaimDeposit(owner);

        uint256 lastRequestId = lastDepositRequestId[owner];
        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        epochs[lastRequestId].depositRequestBalance[owner] = 0;
        _update(address(claimableSilo), receiver, shares);
        emit ClaimDeposit(lastRequestId, owner, receiver, assets, shares);
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
        uint256 lastRequestId = lastRedeemRequestId[owner];
        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        epochs[lastRequestId].redeemRequestBalance[owner] = 0;
        _asset.safeTransferFrom(address(claimableSilo), address(this), assets);
        _asset.transfer(receiver, assets);
        emit ClaimRedeem(lastRequestId, owner, receiver, assets, shares);
    }

    function _settle(uint256 newSavedBalance)
        internal
        onlyOwner
        whenNotPaused
        whenClosed
        returns (uint256, uint256)
    {
        (
            uint256 assetsToOwner,
            uint256 assetsToVault,
            SettleValues memory settleValues
        ) = previewSettle(newSavedBalance);

        emit EpochEnd(
            block.timestamp,
            lastSavedBalance,
            newSavedBalance,
            settleValues.fees,
            totalSupply()
        );

        // Settle the shares balance
        _burn(address(pendingSilo), settleValues.pendingRedeem);
        _mint(address(claimableSilo), settleValues.sharesToMint);

        ///////////////////////////
        // Settle assets balance //
        ///////////////////////////
        // either there are more deposits than withdrawals
        if (settleValues.pendingDeposit > settleValues.assetsToWithdraw) {
            _asset.safeTransferFrom(
                address(pendingSilo), owner(), assetsToOwner
            );
            if (settleValues.assetsToWithdraw > 0) {
                _asset.safeTransferFrom(
                    address(pendingSilo),
                    address(claimableSilo),
                    settleValues.assetsToWithdraw
                );
            }
        } else if (settleValues.pendingDeposit < settleValues.assetsToWithdraw)
        {
            _asset.safeTransferFrom(
                owner(), address(claimableSilo), assetsToVault
            );
            if (settleValues.pendingDeposit > 0) {
                _asset.safeTransferFrom(
                    address(pendingSilo),
                    address(claimableSilo),
                    settleValues.pendingDeposit
                );
            }
        } else if (settleValues.pendingDeposit > 0) {
            // if _pendingDeposit == assetsToWithdraw AND _pendingDeposit > 0
            // (and assetsToWithdraw > 0)
            _asset.safeTransferFrom(
                address(pendingSilo),
                address(claimableSilo),
                settleValues.assetsToWithdraw
            );
        }

        emit Deposit(
            address(pendingSilo),
            address(claimableSilo),
            settleValues.pendingDeposit,
            settleValues.sharesToMint
        );

        emit Withdraw(
            address(pendingSilo),
            address(claimableSilo),
            address(pendingSilo),
            settleValues.assetsToWithdraw,
            settleValues.pendingRedeem
        );

        settleValues.lastSavedBalance = settleValues.lastSavedBalance
            - settleValues.fees + settleValues.pendingDeposit
            - settleValues.assetsToWithdraw;
        lastSavedBalance = settleValues.lastSavedBalance;

        epochs[epochId].totalSupplySnapshotForDeposit =
            settleValues.totalSupplySnapshotForDeposit;
        epochs[epochId].totalAssetsSnapshotForDeposit =
            settleValues.totalAssetsSnapshotForDeposit;
        epochs[epochId].totalSupplySnapshotForRedeem =
            settleValues.totalSupplySnapshotForRedeem;
        epochs[epochId].totalAssetsSnapshotForRedeem =
            settleValues.totalAssetsSnapshotForRedeem;

        epochId++;

        return (settleValues.lastSavedBalance, totalSupply());
    }

    function isCurrentEpoch(uint256 requestId) internal view returns (bool) {
        return requestId == epochId;
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
        uint256 totalSupply =
            epochs[requestId].totalSupplySnapshotForDeposit + 1;

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
        uint256 totalSupply = epochs[requestId].totalSupplySnapshotForRedeem + 1;

        return shares.mulDiv(totalAssets, totalSupply, rounding);
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
            fees = (profits).mulDiv(feesInBps, BPS_DIVIDER, Math.Rounding.Floor);
        }
    }
}
