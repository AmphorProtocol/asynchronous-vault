//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    IERC7540,
    IERC165,
    IERC7540Redeem,
    IERC7540Deposit
} from "./interfaces/IERC7540.sol";
import { ERC7540Receiver } from "./interfaces/ERC7540Receiver.sol";
import { IERC20, SafeERC20, Math, PermitParams } from "./SyncVault.sol";

import { SyncVault } from "./SyncVault.sol";

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
 *         @@@@@@@@@@@@@@@@@@*   Async   *@@@@@@@@@@@@@@@@@@@
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

/**
 * @dev This constant is used to divide the fees by 10_000 to get the percentage
 * of the fees.
 */
uint256 constant BPS_DIVIDER = 10_000;

/*
 * ########
 * # LIBS #
 * ########
*/
using Math for uint256; // only used for `mulDiv` operations.
using SafeERC20 for IERC20; // `safeTransfer` and `safeTransferFrom`

/**
 * @title AsyncVault
 * @dev This structure contains all the informations needed to let user claim
 * their request after we processed those. To avoid rounding errors we store the
 * totalSupply and totalAssets at the time of the deposit/redeem for the deposit
 * and the redeem. We also store the amount of assets and shares given by the
 * user.
 */
struct EpochData {
    uint256 totalSupplySnapshot;
    uint256 totalAssetsSnapshot;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

/**
 * @title SettleValues
 * @dev Hold the required values to settle the vault deposit and
 * redeem requests.
 */
struct SettleValues {
    uint256 lastSavedBalance;
    uint256 fees;
    uint256 pendingRedeem;
    uint256 sharesToMint;
    uint256 pendingDeposit;
    uint256 assetsToWithdraw;
    uint256 totalAssetsSnapshot;
    uint256 totalSupplySnapshot;
}

/**
 * @title Silo
 * @dev This contract is used to hold the assets/shares of the users that
 * requested a deposit/redeem. It is used to simplify the logic of the vault.
 */
contract Silo {
    constructor(IERC20 underlying) {
        underlying.forceApprove(msg.sender, type(uint256).max);
    }
}

contract AsyncVault is IERC7540, SyncVault {
    /*
     * ####################################
     * # AMPHOR SYNTHETIC RELATED STORAGE #
     * ####################################
    */

    /**
     * @notice The epochId is used to keep track of the deposit and redeem
     * requests. It is incremented every time the owner calls the `settle`
     * function.
     */
    uint256 public epochId;
    /**
     * @notice The treasury is used to store the address of the treasury.
     * The treasury is used to store the fees taken from the vault.
     * The treasury can be the owner of the contract or a specific address.
     * The treasury can be changed by the owner of the contract.
     * The treasury can be used to store the fees taken from the vault.
     * The treasury can be the owner of the contract or a specific address.
     */
    address public treasury;
    /**
     * @notice The lastSavedBalance is used to keep track of the assets in the
     * vault at the time of the last `settle` call.
     */
    Silo public pendingSilo;
    /**
     * @notice The claimableSilo is used to hold the assets/shares of the users
     * that requested a deposit/redeem.
     */
    Silo public claimableSilo;
    /**
     * @notice The epochs mapping is used to store the informations needed to
     * let user claim their request after we processed those. To avoid rounding
     * errors we store the totalSupply and totalAssets at the time of the
     * deposit/redeem for the deposit and the redeem. We also store the amount
     * of assets and shares given by the user.
     */
    mapping(uint256 epochId => EpochData epoch) public epochs;
    /**
     * @notice The lastDepositRequestId is used to keep track of the last
     * deposit
     * request made by the user. It is used to let the user claim their request
     * after we processed those.
     */
    mapping(address user => uint256 epochId) public lastDepositRequestId;
    /**
     * @notice The lastRedeemRequestId is used to keep track of the last redeem
     * request made by the user. It is used to let the user claim their request
     * after we processed those.
     */
    mapping(address user => uint256 epochId) public lastRedeemRequestId;

    /*
     * ##########
     * # EVENTS #
     * ##########
    */

    /**
     * @notice This event is emitted when a user request a deposit.
     * @param requestId The id of the request.
     * @param owner The address of the user that requested the deposit.
     * @param previousRequestedAssets The amount of assets requested by the user
     * before the new request.
     * @param newRequestedAssets The amount of assets requested by the user.
     */
    event DecreaseDepositRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedAssets,
        uint256 newRequestedAssets
    );

    /**
     * @notice This event is emitted when a user request a redeem.
     * @param requestId The id of the request.
     * @param owner The address of the user that requested the redeem.
     * @param previousRequestedShares The amount of shares requested by the user
     * before the new request.
     * @param newRequestedShares The amount of shares requested by the user.
     */
    event DecreaseRedeemRequest(
        uint256 indexed requestId,
        address indexed owner,
        uint256 indexed previousRequestedShares,
        uint256 newRequestedShares
    );

    /**
     * @notice This event is emitted when a user request a redeem.
     * @param requestId The id of the request.
     * @param owner The address of the user that requested the redeem.
     * @param receiver The amount of shares requested by the user
     * before the new request.
     * @param assets The amount of shares requested by the user.
     * @param shares The amount of shares requested by the user.
     */
    event ClaimDeposit(
        uint256 indexed requestId,
        address indexed owner,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /**
     * @notice This event is emitted when a user request a redeem.
     * @param requestId The id of the request.
     * @param owner The address of the user that requested the redeem.
     * @param receiver The amount of shares requested by the user
     * before the new request.
     * @param assets The amount of shares requested by the user.
     * @param shares The amount of shares requested by the user.
     */
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

    /**
     * @notice This error is emitted when the user request more shares than the
     * maximum allowed.
     * @param receiver The address of the user that requested the redeem.
     * @param shares The amount of shares requested by the user.
     */
    error ExceededMaxRedeemRequest(
        address receiver, uint256 shares, uint256 maxShares
    );

    /**
     * @notice This error is emitted when the user request more assets than the
     * maximum allowed.
     * @param receiver The address of the user that requested the deposit.
     * @param assets The amount of assets requested by the user.
     * @param maxDeposit The maximum amount of assets the user can request.
     */
    error ExceededMaxDepositRequest(
        address receiver, uint256 assets, uint256 maxDeposit
    );

    /**
     * @notice This error is emitted when the user try to make a new request
     * with an incorrect data.
     */
    error ReceiverFailed();
    /**
     * @notice This error is emitted when the user try to make a new request
     * on behalf of someone else.
     */
    error ERC7540CantRequestDepositOnBehalfOf();
    /**
     * @notice This error is emitted when the user try to make a request
     * when there is no claimable request available.
     */
    error NoClaimAvailable(address owner);
    /**
     * @notice This error is emitted when the user try to make a request
     * when the vault is open.
     */
    error InvalidTreasury();

    /*
     * ##############################
     * # AMPHOR SYNTHETIC FUNCTIONS #
     * ##############################
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() SyncVault() {
        _disableInitializers();
    }

    function initialize(
        uint16 fees,
        address owner,
        address _treasury,
        IERC20 underlying,
        uint256 bootstrapAmount,
        string memory name,
        string memory symbol
    )
        public
        initializer
    {
        super.initialize(fees, owner, underlying, bootstrapAmount, name, symbol);
        epochId = 1;
        setTreasury(_treasury);
        pendingSilo = new Silo(underlying);
        claimableSilo = new Silo(underlying);
    }

    /**
     * @dev This function is used to decrease the amount of assets requested to
     * deposit by the user. It can only be called by the user who made the
     * request.
     * @param assets The amount of assets requested by the user.
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

    /**
     * @dev This function is used to decrease the amount of shares requested to
     * redeem by the user. It can only be called by the user who made the
     * request.
     * @param shares The amount of shares requested by the user.
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
     * @dev The `setTreasury` function is used to set the treasury address.
     * It can only be called by the owner of the contract (`onlyOwner`
     * modifier).
     * @param _treasury The address of the treasury.
     */
    function setTreasury(address _treasury) public onlyOwner {
        if (_treasury == address(0)) revert InvalidTreasury();
        treasury = _treasury;
    }

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

    /**
     * @dev The `settle` function is used to settle the vault.
     * @notice The `settle` function is used to settle the vault. It can only be
     * called by the owner of the contract (`onlyOwner` modifier).
     * If there are profits, the performance fees are taken and sent to the
     * owner of the contract.
     * Since amphor strategies can be time sensitive, we must be able to switch
     * epoch without needing to put all the funds back.
     * Using _settle we can virtually put back the funds, check how much we owe
     * to users that want to redeem and maybe take the extra funds from the
     * deposit requests.
     * @param newSavedBalance The underlying assets amount to be deposited into
     * the vault.
     */
    function settle(uint256 newSavedBalance)
        external
        onlyOwner
        whenNotPaused
        whenClosed
    {
        (uint256 _lastSavedBalance, uint256 totalSupply) =
            _settle(newSavedBalance);
        emit EpochStart(block.timestamp, _lastSavedBalance, totalSupply);
    }

    /**
     * @dev pendingRedeemRequest is used to know how many shares are currently
     * waiting to be redeemed for the user.
     * @param owner The address of the user that requested the redeem.
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
     * via the `claimRedeem` function.
     * @param owner The address of the user that requested the redeem.
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
     * @param owner The address of the user that requested the deposit.
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
     * @param owner The address of the user that requested the deposit.
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
     * @return The amount of assets waiting to be deposited.
     */
    function totalPendingDeposits() external view returns (uint256) {
        return vaultIsOpen ? 0 : _asset.balanceOf(address(pendingSilo));
    }

    /**
     * @dev How many shares are  waiting to be redeemed for all users.
     * @return The amount of shares waiting to be redeemed.
     */
    function totalPendingRedeems() external view returns (uint256) {
        return vaultIsOpen ? 0 : balanceOf(address(pendingSilo));
    }

    /**
     * @dev How many shares are  virtually waiting for the user to be redeemed
     * via the `claimRedeem` function.
     * @return The amount of shares waiting to be redeemed.
     */
    function totalClaimableShares() external view returns (uint256) {
        return balanceOf(address(claimableSilo));
    }

    /**
     * @dev How many assets are virtually waiting for the user to be deposit
     * via the `claimDeposit` function.
     * @return The amount of assets waiting to be deposited.
     */
    function totalClaimableAssets() external view returns (uint256) {
        return _asset.balanceOf(address(claimableSilo));
    }

    /**
     * @dev when the vault is closed, users can only request to deposit.
     * By doing this funds will be sent and wait in the pendingSilo.
     * When the owner will call the `open` or `settle` function, the funds will
     * be deposited and the minted shares will be sent to the claimableSilo.
     * Waiting for the users to claim them.
     * @param assets The amount of assets requested by the user.
     * @param receiver The address of the user that requested the deposit.
     * @param owner The address of the user that requested the deposit.
     * @param data The data to be sent to the receiver.
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
            _claimDeposit(receiver, receiver);
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
     * be redeemed and the assets will be sent to the claimableSilo. Waiting for
     * the users to claim them.
     * @param shares The amount of shares requested by the user.
     * @param receiver The address of the user that requested the redeem.
     * @param owner The address of the user that requested the redeem.
     * @param data The data to be sent to the receiver.
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
            _claimRedeem(receiver, receiver);
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
     * @param receiver The address of the user that requested the deposit.
     */
    function claimDeposit(address receiver)
        public
        whenNotPaused
        returns (uint256 shares)
    {
        return _claimDeposit(_msgSender(), receiver);
    }

    /**
     * @dev This function let users claim the assets we owe them after we
     * processed their redeem request, in the _settle function.
     * @param receiver The address of the user that requested the redeem.
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
     * @param assets The amount of assets requested by the user.
     * @param receiver The address of the user that requested the deposit.
     * @param data The data to be sent to the receiver.
     * @param permitParams The permit signature.
     */
    function requestDepositWithPermit(
        uint256 assets,
        address receiver,
        bytes memory data,
        PermitParams calldata permitParams
    )
        public
    {
        address _msgSender = _msgSender();
        if (_asset.allowance(_msgSender, address(this)) < assets) {
            execPermit(_msgSender, address(this), permitParams);
        }
        return requestDeposit(assets, receiver, _msgSender, data);
    }

    /**
     * @dev users can request deposit only when the vault is closed and not
     * paused.
     * @return The maximum amount of assets the user can request.
     */
    function maxDepositRequest(address) public view returns (uint256) {
        return vaultIsOpen || paused() ? 0 : type(uint256).max;
    }

    /**
     * @dev users can request redeem only when the vault is closed and not
     * paused.
     * @param owner The address of the user that requested the redeem.
     * @return The maximum amount of shares the user can request.
     */
    function maxRedeemRequest(address owner) public view returns (uint256) {
        return vaultIsOpen || paused() ? 0 : balanceOf(owner);
    }

    /**
     * @dev This function let users preview how many shares they will get if
     * they claim their deposit request.
     * @param owner The address of the user that requested the deposit.
     * @return The amount of shares the user will get if they claim their
     * deposit request.
     * @notice This function let users preview how many shares they will get if
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
     * @param owner The address of the user that requested the redeem.
     * @return The amount of assets the user will get if they claim their
     * redeem request.
     */
    function previewClaimRedeem(address owner) public view returns (uint256) {
        uint256 lastRequestId = lastRedeemRequestId[owner];
        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        return _convertToAssets(shares, lastRequestId, Math.Rounding.Floor);
    }

    /**
     * @dev This function convertToShares is used to convert the assets into
     * shares.
     * @param assets The amount of assets to convert.
     * @param _epochId The epoch id.
     * @return The amount of shares.
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

    /**
     * @dev This function convertToAssets is used to convert the shares into
     * assets.
     * @param shares The amount of shares to convert.
     * @param _epochId The epoch id.
     * @return The amount of assets.
     */
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
     * Utils function to convert the shares claimable into assets. It can
     * be used in the front end to save an rpc call.
     */
    /**
     * @dev This function claimableDepositBalanceInAsset is used to know if the
     * owner will have to send money to the claimableSilo (for users who want to
     * leave the vault) or if he will receive money from it.
     * @notice Using this the owner can know if he will have to send money to
     * the
     * claimableSilo (for users who want to leave the vault) or if he will
     * receive money from it.
     * @param owner The address of the user that requested the deposit.
     * @return The amount of assets the user will get if they claim their
     * deposit request.
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
     * @dev This function claimableRedeemBalanceInAsset is used to know if the
     * owner will have to send money to the claimableSilo (for users who want to
     * leave the vault) or if he will receive money from it.
     * @param newSavedBalance The underlying assets amount to be deposited into
     * the vault.
     * @return assetsToOwner The amount of assets the
     * user will get if they claim their redeem request.
     * @return assetsToVault The amount of assets the user will get if
     * they claim their redeem request.
     * @return expectedAssetFromOwner The amount of assets that will be taken
     * from the owner.
     * @return settleValues The settle values.
     */
    function previewSettle(uint256 newSavedBalance)
        public
        view
        returns (
            uint256 assetsToOwner,
            uint256 assetsToVault,
            uint256 expectedAssetFromOwner,
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

        uint256 totalAssetsSnapshot = _lastSavedBalance;
        uint256 totalSupplySnapshot = totalSupply;

        uint256 assetsToWithdraw = pendingRedeem.mulDiv(
            _lastSavedBalance + pendingDeposit + 1,
            totalSupply + sharesToMint + 1,
            Math.Rounding.Floor
        );

        settleValues = SettleValues({
            lastSavedBalance: _lastSavedBalance + fees,
            fees: fees,
            pendingRedeem: pendingRedeem,
            sharesToMint: sharesToMint,
            pendingDeposit: pendingDeposit,
            assetsToWithdraw: assetsToWithdraw,
            totalAssetsSnapshot: totalAssetsSnapshot,
            totalSupplySnapshot: totalSupplySnapshot
        });

        if (pendingDeposit > assetsToWithdraw) {
            assetsToOwner = pendingDeposit - assetsToWithdraw;
        } else if (pendingDeposit < assetsToWithdraw) {
            assetsToVault = assetsToWithdraw - pendingDeposit;
        }
        expectedAssetFromOwner = fees + assetsToVault;
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
    /**
     * @dev _createDepositRequest is used to update the balance of the user in
     * order to create the deposit request.
     * @param assets The amount of assets requested by the user.
     * @param receiver The address of the user that requested the deposit.
     * @param owner The address of the user that requested the deposit.
     */
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
                    _msgSender(), owner, epochId, assets, data
                ) != ERC7540Receiver.onERC7540DepositReceived.selector
        ) revert ReceiverFailed();

        emit DepositRequest(receiver, owner, epochId, _msgSender(), assets);
    }

    /**
     * @dev _createRedeemRequest is used to update the balance of the user in
     * order to create the redeem request.
     * @param shares The amount of shares requested by the user.
     * @param receiver The address of the user that requested the redeem.
     * @param owner The address of the user that requested the redeem.
     * @param data The data to be sent to the receiver.
     * @notice This function is used to update the balance of the user.
     */
    function _createRedeemRequest(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory data
    )
        internal
    {
        epochs[epochId].redeemRequestBalance[receiver] += shares;
        if (lastRedeemRequestId[receiver] != epochId) {
            lastRedeemRequestId[receiver] = epochId;
        }

        if (
            data.length > 0
                && ERC7540Receiver(receiver).onERC7540RedeemReceived(
                    _msgSender(), owner, epochId, shares, data
                ) != ERC7540Receiver.onERC7540RedeemReceived.selector
        ) revert ReceiverFailed();

        emit RedeemRequest(receiver, owner, epochId, _msgSender(), shares);
    }

    /**
     * @dev _claimDeposit is used to claim the pending deposit.
     * @param owner The address of the user that requested the deposit.
     * @param receiver The address of the user that requested the deposit.
     * @return shares The amount of shares requested by the user.
     */
    function _claimDeposit(
        address owner,
        address receiver
    )
        internal
        returns (uint256 shares)
    {
        uint256 lastRequestId = lastDepositRequestId[owner];
        if (lastRequestId == epochId) revert NoClaimAvailable(owner);

        shares = previewClaimDeposit(owner);

        uint256 assets = epochs[lastRequestId].depositRequestBalance[owner];
        epochs[lastRequestId].depositRequestBalance[owner] = 0;
        _update(address(claimableSilo), receiver, shares);
        emit ClaimDeposit(lastRequestId, owner, receiver, assets, shares);
    }

    /**
     * @dev _claimRedeem is used to claim the pending redeem and request a new
     * one in one transaction.
     * @param owner The address of the user that requested the redeem.
     * @param receiver The address of the user that requested the redeem.
     * @return assets The amount of assets requested by the user.
     */
    function _claimRedeem(
        address owner,
        address receiver
    )
        internal
        whenNotPaused
        returns (uint256 assets)
    {
        uint256 lastRequestId = lastRedeemRequestId[owner];
        if (lastRequestId == epochId) revert NoClaimAvailable(owner);

        assets = previewClaimRedeem(owner);

        uint256 shares = epochs[lastRequestId].redeemRequestBalance[owner];
        epochs[lastRequestId].redeemRequestBalance[owner] = 0;
        _asset.safeTransferFrom(address(claimableSilo), receiver, assets);
        emit ClaimRedeem(lastRequestId, owner, receiver, assets, shares);
    }

    /**
     * @dev _settle is used to settle the vault.
     * @param newSavedBalance The underlying assets amount to be deposited into
     * the vault.
     * @return lastSavedBalance The last saved balance.
     * @return totalSupply The total supply.
     */
    function _settle(uint256 newSavedBalance)
        internal
        returns (uint256, uint256)
    {
        (
            uint256 assetsToOwner,
            uint256 assetsToVault,
            ,
            SettleValues memory settleValues
        ) = previewSettle(newSavedBalance);

        emit EpochEnd(
            block.timestamp,
            lastSavedBalance,
            newSavedBalance,
            settleValues.fees,
            totalSupply()
        );

        _asset.safeTransferFrom(owner(), treasury, settleValues.fees);

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

        epochs[epochId].totalSupplySnapshot =
            settleValues.totalSupplySnapshot;
        epochs[epochId].totalAssetsSnapshot =
            settleValues.totalAssetsSnapshot;

        epochId++;

        return (settleValues.lastSavedBalance, totalSupply());
    }

    /**
     * @dev isCurrentEpoch is used to check if the request is the current epoch.
     * @param requestId The id of the request.
     */
    function isCurrentEpoch(uint256 requestId) internal view returns (bool) {
        return requestId == epochId;
    }

    /**
     * @dev _convertToShares is used to convert the assets into shares for a
     * specific epoch/request.
     * @param assets The amount of assets to convert.
     * @param requestId The id of the request.
     * @param rounding The rounding type.
     */
    function _convertToShares(
        uint256 assets,
        uint256 requestId,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        if (isCurrentEpoch(requestId)) return 0;

        uint256 totalAssets = epochs[requestId].totalAssetsSnapshot + 1;
        uint256 totalSupply = epochs[requestId].totalSupplySnapshot + 1;

        return assets.mulDiv(totalSupply, totalAssets, rounding);
    }

    /**
     * @dev _convertToAssets is used to convert the shares into assets for a
     * specific epoch/request.
     * @param shares The amount of shares to convert.
     * @param requestId The id of the request.
     * @param rounding The rounding type.
     */
    function _convertToAssets(
        uint256 shares,
        uint256 requestId,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        if (isCurrentEpoch(requestId)) return 0;

        uint256 totalSupply = epochs[requestId].totalSupplySnapshot + 1;
        uint256 totalAssets = epochs[requestId].totalAssetsSnapshot + 1;

        return shares.mulDiv(totalAssets, totalSupply, rounding);
    }

    /**
     * @dev _checkMaxDrawdown is used to check if the max drawdown is reached.
     * @param _lastSavedBalance The last saved balance.
     * @param newSavedBalance The new saved balance.
     */
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
