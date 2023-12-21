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

contract SynthVault is IERC7540, ERC20Pausable, Ownable2Step, ERC20Permit {

    using Math for uint256;
    using SafeERC20 for IERC20;
    
    // @dev Emitted when an epoch starts.
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

    // @dev The rules doesn't allow the perf fees to be higher than 30.00%.
    error FeesTooHigh();

    // @dev Attempted to deposit more underlying assets than the max amount for
    // `receiver`.
    error ERC4626ExceededMaxDeposit(
        address receiver, uint256 assets, uint256 max
    );

    // @dev Attempted to redeem more shares than the max amount for `receiver`.
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    // The canonical permit2 contract.
    // IPermit2 public immutable permit2;

    
    // @dev The perf fees applied on the positive yield.
    // @return Amount of the perf fees applied on the positive yield.
    uint16 public feesInBps;

    IERC20 public immutable _asset;
    uint256 public epochNonce = 1; // in order to start at epoch 1, otherwise users might try to claim epoch -1 requests
    uint256 public totalAssets; // total working assets (in the strategy), not including pending withdrawals money

    // to manage the pending deposits
    mapping(address owner => mapping(uint256 id => uint256 amount)) public requestDepositBalanceOf;
    uint256 public currentPendingAssets;
    mapping(address owner => uint256) public lastRequestDepositId;

    // to manage the pending withdraws
    mapping(address owner => mapping(uint256 id => uint256 amount)) public requestWithdrawBalanceOf;
    uint256 public pendingShares;
    mapping(address owner => uint256) public lastRequestWithdrawId;

    uint256[] public totalAssetsAtEpoch; //maybe a mapping would be better
    uint256[] public totalSharesAtEpoch; //maybe a mapping would be better

    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol
        // IPermit2 _permit2
    ) ERC20(name, symbol) Ownable(_msgSender()) ERC20Permit(name) {
        _asset = IERC20(underlying);
        // permit2 = _permit2;
    }

    function requestDeposit(uint256 assets, address receiver, address owner) public whenNotPaused {
        uint256 _lastRequestDepositId = lastRequestDepositId[owner];
        if (_lastRequestDepositId != 0 && _lastRequestDepositId != epochNonce) {
            _deposit(owner, receiver, _lastRequestDepositId, requestDepositBalanceOf[owner][_lastRequestDepositId]);
        }
        uint256 _epochNonce = epochNonce;
        // safeTransferFrom(_asset, owner, address(this), assets);
        _asset.safeTransferFrom(owner, address(this), assets);
        requestDepositBalanceOf[owner][_epochNonce] += assets;
        
        lastRequestDepositId[owner] = _epochNonce;
        currentPendingAssets += assets;
    }

    function cancelDepositRequest(uint256 assets, address receiver, address owner) external whenNotPaused {
        requestDepositBalanceOf[owner][epochNonce] -= assets;
        currentPendingAssets -= assets;
        _asset.safeTransfer(receiver, assets);
    }

    function pendingDepositRequest(address owner) external view returns (uint256 assets) {
        return requestDepositBalanceOf[owner][lastRequestDepositId[owner]];
    }

    function requestRedeem(uint256 shares, address receiver, address owner, bytes memory) external whenNotPaused {
       // Claim not claimed request
    //     uint256 lastRequestId = depositRequestLP.lastRequestId(owner);
    //     uint256 lastRequestBalance = depositRequestLP.balanceOf(owner, lastRequestId);
    //     if (lastRequestBalance > 0 && lastRequestId != epochNonce) // We don't want to call _redeem for nothing and we don't want to cancel a current request if the user just want to increase it.
    //         _redeem(owner, receiver, lastRequestId, lastRequestBalance);

    //     withdrawRequestLP.deposit(epochNonce, shares, receiver, owner);
    //    //TODO emit event ?
    }

    // function withdrawRedeemRequest(uint256 shares, address receiver, address owner) external whenNotPaused {
    //     withdrawRequestLP.withdraw(epochNonce, shares, receiver, owner);
    //    //TODO emit event ?
    // }

    function pendingRedeemRequest(address owner) external view returns (uint256 shares) {
        return 0;
        // return withdrawRequestLP.balanceOf(owner, epochNonce);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId;
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
        
        uint256 _lastRequestDepositId = lastRequestDepositId[owner];
        if (_lastRequestDepositId == 0 || _lastRequestDepositId == epochNonce) return 0;
        return requestDepositBalanceOf[owner][_lastRequestDepositId];
    }

    // // TODO: implement this correclty if possible
    function maxMint(address) public pure returns (uint256) {
        return 0;
    }

    // // TODO: implement this correclty if possible
    function maxWithdraw(address) public pure returns (uint256) {
        return 0; // check if the rounding is correct
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return 0;
        // return withdrawRequestLP.balanceOf(owner, epochNonce - 1);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertRequestDepositToShares(epochNonce - 1, assets, Math.Rounding.Floor);
    }



    function previewDeposit(uint256 epochId, uint256 assets) public view returns (uint256) {
        return _convertRequestDepositToShares(epochId, assets, Math.Rounding.Floor);
    }

    function _convertRequestDepositToShares(uint256 epochId, uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        if (epochId == epochNonce) return 0;
        return assets.mulDiv(
            totalSharesAtEpoch[epochId] + 1, totalAssetsAtEpoch[epochId] + 1, rounding
        );
    }

    // TODO implement this correctly if possible
    function previewMint(uint256) public pure returns (uint256) {
        return 0;
    }

    // TODO implement this correctly if possible
    function previewWithdraw(uint256) public pure returns (uint256) {
        return 0;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return 0;
        // return _convertWithdrawLPToAssets(epochNonce - 1, shares, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver)
        public
        whenNotPaused
        returns (uint256)
    {
        address owner = _msgSender();
        return _deposit(owner, receiver, lastRequestDepositId[owner], assets);
    }

    // assets = pending lp balance
    // shares = shares to mint
    function _deposit(address owner, address receiver, uint256 requestId, uint256 assets)
        internal
        returns (uint256)
    {
        uint256 maxAssets = maxDeposit(owner); // what he can claim from the last epoch request 
        if (assets > maxAssets) { // he is trying to claim more than he can by saying he has more pending lp that he has in reality
            revert ERC4626ExceededMaxDeposit(owner, assets, maxAssets);
        }

        uint256 sharesAmount = previewDeposit(requestId, assets);
        requestDepositBalanceOf[owner][requestId] -= assets; // decrease the currentPendingAssets
        IERC20(address(this)).transfer(receiver, sharesAmount); // transfer the vault shares to the receiver

        emit Deposit(owner, receiver, assets, sharesAmount);

        return sharesAmount;
    }

    // TODO: implement this correclty if possible
    function mint(uint256, address) public pure returns (uint256) {
        return 0;
    }

    // TODO: implement this correclty if possible
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
        return 0;
        // return _redeem(owner, receiver, epochNonce - 1, shares);
    }
    
    // function _redeem(address owner, address receiver, uint256 requestId, uint256 shares)
    //     internal
    //     returns (uint256)
    // {
    //     uint256 maxShares = maxRedeem(owner);
    //     if (shares > maxShares) revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);

    //     uint256 assetsAmount = previewRedeem(shares);
    //     withdrawRequestLP.burn(owner, requestId, shares);

    //     _asset.safeTransfer(receiver, assetsAmount);
    //     pendingAssets[requestId] -= assetsAmount; // decrease the currentPendingAssets

    //     emit Withdraw(_msgSender(), receiver, owner, assetsAmount, shares);

    //     return assetsAmount;
    // }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(
            totalSupply() + 1, totalAssets + 1, rounding
        );
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return shares.mulDiv(
            totalAssets + 1, totalSupply() + 1, rounding
        );
    }

    // TODO: implement this
    function nextEpoch(uint256 returnedUnderlyingAmount) public onlyOwner returns (uint256) {
    // (end + start epochs)

    // TODO
    // 1. take fees from returnedUnderlyingAmount
    // 2. we update the totalAssets
    // 3. with the resting amount we know how much cost a share
    // 4. we can take the pending deposits underlying (same as this vault underlying) and mint shares
    // 5. we update the bigShares array for the appropriate epoch (epoch 0 request is a deposit into epoch 1...)
    // 6. we can take the pending withdraws shares and redeem underlying (which are shares of this vault) against this vault underlying
    // 7. we update the pendingAssets array for the appropriate epoch (epoch 0 request is a withdraw at the end of the epoch 0...)

    ///////////////////////
    // Ending current epoch
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

    // Can be done in one time at the end
        SafeERC20.safeTransferFrom(
            _asset, _msgSender(), address(this), returnedUnderlyingAmount - fees
        );

        emit EpochEnd(
            block.timestamp,
            totalAssets,
            returnedUnderlyingAmount,
            fees,
            totalSupply()
        );

        totalSharesAtEpoch.push(totalSupply());
        totalAssetsAtEpoch.push(totalAssets);

        uint256 toMint = previewDeposit(epochNonce, currentPendingAssets); // get the shares of the pending deposits


   
    // Minting the shares
        _mint(address(this), toMint ); // mint the shares into the vault
    // Update the totalAssets
        totalAssets += currentPendingAssets;

        currentPendingAssets = 0;
    // Burn the vault shares
        // _burn(address(this), pendingRedeem); // burn the shares from the vault
    // Update the totalAssets
        // totalAssets -= pendingAssets;

        _asset.safeTransfer(owner(), totalAssets);

        emit EpochStart(block.timestamp, totalAssets, totalSupply());

        return ++epochNonce;
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

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) whenNotPaused {
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