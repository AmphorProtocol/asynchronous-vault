//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC7540, IERC165, IERC7540Redeem } from "./interfaces/IERC7540.sol";
import { ERC7540Receiver } from "./interfaces/ERC7540Receiver.sol";
import {
    IERC20,
    SafeERC20,
    IAllowanceTransfer,
    Math,
    PermitParams
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
    uint256 totalSupplySnapshot;
    uint256 totalAssetsSnapshot;
    mapping(address => uint256) depositRequestBalance;
    mapping(address => uint256) redeemRequestBalance;
}

uint256 constant BPS_DIVIDER = 10_000;
uint16 constant MAX_FEES = 3000; // 30%

contract AsyncSynthVault is
    IERC7540,
    SyncSynthVault {

    /*
     * ####################################
     * # AMPHOR SYNTHETIC RELATED STORAGE #
     * ####################################
    */

    // @return Amount of the perf fees applied on the positive yield.
    uint256 public epochId;
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
    error ClaimableRequestPending();
    error MustClaimFirst();
    error ReceiverFailed();

    /*
     * ##############################
     * # AMPHOR SYNTHETIC FUNCTIONS #
     * ##############################
     */

    modifier whenNoClaimableDepositRequest(address receiver) {
        // Check if the user has a claimable request
        uint256 lastRequestId = lastDepositRequestId[receiver];
        uint256 lastRequestBalance =
            epochs[lastRequestId].depositRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochId;

        if (hasClaimableRequest) revert MustClaimFirst();
        _;
    }

    modifier whenNoClaimableRedeemRequest(address receiver) {
        // Check if the user has a claimable request
        uint256 lastRequestId = lastRedeemRequestId[receiver];
        uint256 lastRequestBalance =
            epochs[lastRequestId].redeemRequestBalance[receiver];
        bool hasClaimableRequest =
            lastRequestBalance > 0 && lastRequestId != epochId;

        if (hasClaimableRequest) revert MustClaimFirst();
        _;
    }

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
        initializer
        override
    {
        super.initialize(fees, owner, underlying, name, symbol);
        epochId = 1;
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
        whenNoClaimableDepositRequest(receiver)
    {
        if (_msgSender() != owner) {
            revert();
        }
        if (assets > maxDepositRequest(receiver)) {
            revert ExceededMaxDepositRequest(
                receiver, assets, maxDepositRequest(receiver)
            );
        }

        // Create a new request

        _ASSET.safeTransferFrom(owner, address(this), assets);

        _createDepositRequest(assets, receiver, owner, data);
    }

    // transfer must happen before this function is called TOOD maybe change
    // this
    function _createDepositRequest(
        uint256 assets,
        address receiver,
        address owner,
        bytes memory data
    )
        internal
    {
        if (
            _msgSender() != owner
                && _ASSET.allowance(owner, _msgSender()) >= assets
        ) {
            SafeERC20.safeTransferFrom(_ASSET, owner, address(this), assets);
        }

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

    // tree done
    function pendingDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        return epochs[lastDepositRequestId[owner]].depositRequestBalance[owner];
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
        whenNoClaimableRedeemRequest(receiver)
    {
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
        if (_msgSender() != owner) _spendAllowance(owner, _msgSender(), shares);

        transferFrom(owner, address(this), shares);
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

    function claimDeposit(
        address receiver
    )
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

        emit Withdraw(owner, owner, address(this), assets, shares);
        emit Deposit(owner, owner, assets, shares);
        emit ClaimDeposit(lastRequestId, owner, receiver, assets,
        shares);
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
        uint256 pendingDeposit = _ASSET.balanceOf(address(this));
        _open(assetReturned);
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
        if (_ASSET.allowance(owner, address(this)) < assets) {
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
    {
        address owner = _msgSender();
        execPermit2(permitSingle, signature);
        permit2.transferFrom(
            owner, address(this), uint160(assets), address(_ASSET)
        );

        _createDepositRequest(assets, receiver, owner, data);
    }
}
