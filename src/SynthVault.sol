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
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct Permit2Params {
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    address token;
    bytes signature;
}


struct PendingDeposit {
    uint256 epochId;
    uint256 assets;
}

struct PendingRedeem {
    uint256 epochId;
    uint256 shares;
}

struct Epoch {
    uint256 totalAssets;
    uint256 supply;
}

contract SynthVault is IERC7540, ERC20Pausable, Ownable2Step, ERC20Permit {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // @dev Emitted when an epoch starts. At this moment, funds are sent to the
    // owner.
    // @param timestamp The block timestamp of the epoch start.
    // @param lastSavedBalance The `lastSavedBalance` when the vault start.
    // @param totalShares The total amount of shares when the vault star
    event EpochStart(
        uint256 indexed timestamp, uint256 lastSavedBalance, uint256 totalShares
    );

    // @dev Emitted when an epoch ends.
    // @param timestamp The block timestamp of the epoch end.
    // @param lastSavedBalance The `lastSavedBalance` when the vault end.
    // @param returnedAssets The total amount of underlying assets returned to
    // the vault before collecting fees.
    // @param fees The amount of fees collected.
    // @param totalShares The total amount of shares when the vault end.
    event EpochEnd(
        uint256 indexed timestamp,
        uint256 lastSavedBalance,
        uint256 returnedAssets,
        uint256 fees,
        uint256 totalShares
    );

    event FeesChanged(uint16 oldFees, uint16 newFees);

    error FeesTooHigh();

    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );

    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    // The canonical permit2 contract.
    // IPermit2 public immutable permit2;

    // @dev The perf fees applied on the positive yield.
    // @return Amount of the perf fees applied on the positive yield.
    uint16 public feesInBps;

    IERC20 public immutable _asset;
    uint256 public currentEpochId = 0;
    uint256 public totalAssets; // total working assets (in the strategy), not including pending withdrawals money


    // to manage the pending deposits
    mapping(address owner => PendingDeposit) public pendingDeposits;
    uint256 public currentEpochPendingAssets; // this variable help us now how much assets are pending to be deposited
                                            // it's possible that we don't need it and compute it on the fly. We will see

    // to manage the pending redeem
    mapping(address owner => PendingRedeem) public pendingRedeems;
    uint256 public currentEpochPendingShares; // this variable help us now how much shares are pending to be redeemed


    // summary of each epoch total assets and total shares in order to calculate the shares price
    mapping(uint256 => Epoch) public epochs;

    constructor(ERC20 underlying, string memory name, string memory symbol)
        ERC20(name, symbol)
        Ownable(_msgSender())
        ERC20Permit(name)
    {
        _asset = IERC20(underlying);
    }

    function requestDeposit(uint256 assets, address receiver, address owner)
        public
        whenNotPaused
    {
        uint256 _currentEpochId = currentEpochId;

        // a user can only have one pending deposit at a time. If he wants to request a deposit while he already has one, we will redeem the pending deposit and add the new one.
        PendingDeposit storage pendingDeposit = pendingDeposits[owner];
        if (pendingDeposit.assets != 0 && pendingDeposit.epochId != _currentEpochId) {
            _deposit(
                owner,
                receiver,
                pendingDeposit.epochId,
                pendingDeposit.assets
            );
        }

        _asset.safeTransferFrom(owner, address(this), assets);
        pendingDeposit.assets += assets;

        if (pendingDeposit.epochId != _currentEpochId) 
            pendingDeposit.epochId = _currentEpochId;
        
        currentEpochPendingAssets += assets;
    }

    function cancelDepositRequest(
        uint256 assets,
        address receiver,
        address owner
    ) external whenNotPaused {
        pendingDeposits[owner].assets -= assets;
        currentEpochPendingAssets -= assets; 
        _asset.safeTransfer(receiver, assets);
    }

    function pendingDepositRequest(address owner)
        external
        view
        returns (uint256 assets)
    {
        return pendingDeposits[owner].assets;
    }

    function requestRedeem(
        uint256 shares,
        address receiver,
        address owner,
        bytes memory
    ) external whenNotPaused {
        // to make the logic easier, we will redeem the pending redeem if any before adding the new one
        PendingRedeem storage pendingRedeem = pendingRedeems[owner];
        uint256 _currentEpochId = currentEpochId;
        if (
            pendingRedeem.epochId != 0 && pendingRedeem.epochId != _currentEpochId // We don't want to call _redeem for nothing and we don't want to cancel a current request if the user just want to increase it.
        ) {
            _redeem(
                owner,
                receiver,
                pendingRedeem.epochId,
                pendingRedeem.shares
            );
        }

       transferFrom(owner, address(this), shares);
        pendingRedeem.shares += shares;
        if (pendingRedeem.epochId != _currentEpochId) 
            pendingRedeem.epochId = _currentEpochId;
        currentEpochPendingShares += shares;
    }

    function withdrawRedeemRequest(
        uint256 shares,
        address receiver,
        address owner
    ) external whenNotPaused {
        pendingRedeems[owner].shares -= shares;
        currentEpochPendingShares -= shares; //todo remove
        transfer(receiver, shares);
    }

    function pendingRedeemRequest(address owner)
        external
        view
        returns (uint256 shares)
    {
        return pendingRedeems[owner].shares;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    function asset() public view returns (address) {
        return address(_asset);
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function maxDeposit(address owner) public view returns (uint256) {
        PendingDeposit memory pendingDeposit = pendingDeposits[owner];
        if (pendingDeposit.epochId == currentEpochId) {
            return 0;
        }
        return pendingDeposit.assets;
    }

    function maxMint(address) public pure returns (uint256) {
        return 0;
    }

    function maxWithdraw(address) public pure returns (uint256) {
        return 0;
    }

    function maxRedeem(address owner) public view returns (uint256) {
        PendingRedeem memory pendingRedeem = pendingRedeems[owner];
        if (pendingRedeem.epochId == 0 || pendingRedeem.epochId == currentEpochId) {
            return 0;
        }
        return pendingRedeem.shares;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertRequestDepositToShares(
            currentEpochId - 1, assets, Math.Rounding.Floor
        );
    }

    function previewDeposit(uint256 epochId, uint256 assets)
        public
        view
        returns (uint256)
    {
        return
            _convertRequestDepositToShares(epochId, assets, Math.Rounding.Floor);
    }

    function _convertRequestDepositToShares(
        uint256 epochId,
        uint256 assets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        if (epochId == epochId) return 0;
        return assets.mulDiv(
            epochs[epochId].supply + 1,
            epochs[epochId].totalAssets + 1,
            rounding
        );
    }

    function previewMint(uint256) public pure returns (uint256) {
        return 0;
    }

    function previewWithdraw(uint256) public pure returns (uint256) {
        return 0;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertRequestDepositToShares(currentEpochId - 1, shares, Math.Rounding.Floor);
    }

    function previewRedeem(uint256 shares, uint256 _epochId)
        public
        view
        returns (uint256)
    {
        return
            _convertRequestRedeemToAssets(_epochId, shares, Math.Rounding.Floor);
    }

    function _convertRequestRedeemToAssets(
        uint256 epochId,
        uint256 shares,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        if (epochId == currentEpochId) return 0;
        return shares.mulDiv(
            epochs[epochId].totalAssets + 1,
            epochs[epochId].supply + 1,
            rounding
        );
    }

    function deposit(uint256 assets, address receiver)
        public
        whenNotPaused
        returns (uint256)
    {
        address owner = _msgSender();
        return _deposit(owner, receiver, pendingDeposits[owner].epochId, assets);
    }

    function _deposit(
        address owner,
        address receiver,
        uint256 requestId,
        uint256 assets
    ) internal returns (uint256) {
        uint256 maxAssets = maxDeposit(owner); // what he can claim
        if (assets > maxAssets) {
            // he is trying to claim more than he can by saying he has more pending lp that he has in reality
            revert ERC4626ExceededMaxDeposit(owner, assets, maxAssets);
        }

        uint256 sharesAmount = previewDeposit(requestId, assets);
        pendingDeposits[owner].assets -= assets;
        if (assets == maxAssets)
            pendingDeposits[owner].epochId = 0; // reset the pending deposit
        transfer(receiver, sharesAmount);

        emit Deposit(owner, receiver, assets, sharesAmount);

        return sharesAmount;
    }

    function mint(uint256, address) external pure returns (uint256) {
        return 0;
    }

    function withdraw(uint256, address, address)
        external
        pure
        returns (uint256)
    {
        return 0;
    }

    function redeem(uint256 shares, address receiver, address owner)
        external
        whenNotPaused
        returns (uint256)
    {
        return _redeem(owner, receiver, pendingRedeems[owner].epochId, shares);
    }

    function _redeem(
        address owner,
        address receiver,
        uint256 epochId,
        uint256 shares
    ) internal returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 _assets = previewRedeem(shares, epochId);
        if (_assets == 0) return 0; // todo discuss
        pendingRedeems[owner].shares -= shares;

        _asset.safeTransfer(receiver, _assets);
        if (shares == maxShares)
            pendingRedeems[owner].epochId = 0; // reset the pending redeem

        emit Withdraw(_msgSender(), receiver, owner, _assets, shares);

        return _assets;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + 1, totalAssets + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return shares.mulDiv(totalAssets + 1, totalSupply() + 1, rounding);
    }

    // TODO: implement this
    function nextEpoch(uint256 returnedUnderlyingAmount)
        public
        onlyOwner
        returns (uint256)
    {
        ///////////////////////
        // First we end the current epoch
        ///////////////////////
        uint256 fees;

        if (returnedUnderlyingAmount > totalAssets && feesInBps > 0) {
            uint256 profits;
            unchecked {
                profits = returnedUnderlyingAmount - totalAssets;
            }
            fees = (profits).mulDiv(feesInBps, 10000, Math.Rounding.Ceil);
        }

        totalAssets = returnedUnderlyingAmount - fees;

        SafeERC20.safeTransferFrom(
            _asset, _msgSender(), address(this), returnedUnderlyingAmount - fees
        );

        epochs[currentEpochId] = Epoch({
            totalAssets: totalAssets,
            supply: totalSupply()
        });

        emit EpochEnd(
            block.timestamp,
            totalAssets,
            returnedUnderlyingAmount,
            fees,
            totalSupply()
        );

        // Then we register the withdrawals and deposits by updating the amount of shares and assets under management

        uint256 sharesToMint = previewDeposit(currentEpochId, currentEpochPendingAssets);
        uint256 assetToAdd = currentEpochPendingAssets;
        uint256 sharesToBurn = currentEpochPendingShares;
        uint256 assetToRmv = previewRedeem(currentEpochId, currentEpochPendingShares);

        if (sharesToMint > sharesToBurn)
            _mint(address(this), sharesToMint - sharesToBurn );
        else if (sharesToMint < sharesToBurn)
            _burn(address(this), sharesToBurn - sharesToMint);

        totalAssets += assetToAdd - assetToRmv;

        currentEpochPendingAssets = 0;
        currentEpochPendingShares = 0;

        // Finally we start the new epoch by sending back the assets to the owner.

        _asset.safeTransfer(owner(), totalAssets);
        ++currentEpochId;

        emit EpochStart(block.timestamp, totalAssets, totalSupply());

    }

    function setFees(uint16 newFees) external onlyOwner {
        if (newFees > 3000) revert FeesTooHigh(); // hard cap at 30%
        feesInBps = newFees;
        emit FeesChanged(feesInBps, newFees);
    }

    // TODO: implement this correclty

    // @dev The `claimToken` function is used to claim other tokens that have
    // been sent to the vault.
    // @notice The `claimToken` function is used to claim other tokens that have
    // been sent to the vault.
    // It can only be called by the owner of the contract (`onlyOwner` modifier).
    // @param token The IERC20 token to be claimed.
    // function claimToken(IERC20 token) external onlyOwner {
    //     if (token == _asset) {///TODO: get the discrepancy between returned assets and pending depos}
    //     token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    // }

    // Pausability
    // function pause() public onlyOwner {
    //     _pause();
    // }

    // function unpause() public onlyOwner {
    //     _unpause();
    // }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Pausable)
        whenNotPaused
    {
        super._update(from, to, value);
    }

    // Deposit some amount of an ERC20 token into this contract
    // using Permit2.
    // function execPermit2(
    //     Permit2Params calldata permit2Params
    // ) internal {
    //    // Transfer tokens from the caller to ourselves.
    //     permit2.permitTransferFrom(
    //        // The permit message.
    //         ISignatureTransfer.PermitTransferFrom({
    //             permitted: ISignatureTransfer.TokenPermissions({
    //                 token: permit2Params.token,
    //                 amount: permit2Params.amount
    //             }),
    //             nonce: permit2Params.nonce,
    //             deadline: permit2Params.deadline
    //         }),
    //        // The transfer recipient and amount.
    //         ISignatureTransfer.SignatureTransferDetails({
    //             to: address(this),
    //             requestedAmount: permit2Params.amount
    //         }),
    //        // The owner of the tokens, which must also be
    //        // the signer of the message, otherwise this call
    //        // will fail.
    //         _msgSender(),
    //        // The packed signature that was the result of signing
    //        // the EIP712 hash of `permit`.
    //         permit2Params.signature
    //     );
    // }

    // function requestDepositWithPermit2(
    //     uint256 assets,
    //     address receiver,
    //     address owner,
    //     Permit2Params calldata permit2Params
    // ) external {
    //     if (_asset.allowance(owner, address(this)) < assets)
    //         execPermit2(permit2Params);
    //     return requestDeposit(assets, receiver, owner);
    // }
}
