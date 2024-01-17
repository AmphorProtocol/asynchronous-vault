//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    Ownable,
    Ownable2Step
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    ERC4626,
    ERC20,
    IERC20,
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AmprWithdrawReceipt is ERC4626, Ownable2Step {
    /*
     ######
      LIBS
     ######
    */

    /**
     * @dev The `SafeERC20` lib is only used for `safeTransfer` and
     * `safeTransferFrom` operations.
     */
    using SafeERC20 for IERC20;
    /*
     #####################################
      AMPHOR SYNTHETIC RELATED ATTRIBUTES
     #####################################
    */

    /**
     * @dev The address of the treasuryWallet where the underlying is located.
     */
    address private _treasuryWallet;

    address public minter;

    /**
     * @dev The max amount of underlying assets that can be withdrawn.
     */
    uint256 _maxWithdraw;

    /*
     * @dev The max amount of underlying assets that can be deposited.
     */
    uint256 _maxDeposit;

    /*
     ########
      EVENTS
     ########
    */

    /*
     ########
      ERRORS
     ########
    */

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

    error notMinter();

    /*
     ########
      MODIFIERS
     ########
    */

    modifier onlyMinter() {
        if (_msgSender() != minter) revert notMinter();
        _;
    }

    /*
     #############
      CONSTRUCTOR
     #############
    */

    /**
     * @dev The `constructor` function is used to initialize the vault.
     * @param underlying The underlying asset token.
     * @param name The name of the vault.
     * @param symbol The symbol of the vault.
     * @param treasuryWallet The address of the treasuryWallet where the underlying is located.
     */
    constructor(
        ERC20 underlying,
        string memory name,
        string memory symbol,
        address treasuryWallet
    ) ERC4626(underlying) ERC20(name, symbol) Ownable(_msgSender()) {
        _treasuryWallet = treasuryWallet;
    }

    /*
     ####################################
      GENERAL ERC-4626 RELATED FUNCTIONS
     ####################################
    */

    /**
     * @dev The `totalAssets` function is used to calculate the theoretical
     * total underlying assets owned by the vault.
     * If the vault is locked, the last saved balance is added to the current
     * balance.
     * @notice The `totalAssets` function is used to know what is the
     * theoretical TVL of the vault.
     * @return Amount of the total underlying assets in the vault.
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(_treasuryWallet);
    }

    /**
     * @dev See {IERC4626-convertToShares}.
     * @notice The `convertToShares` function is used to calculate shares amount
     * received in exchange of the specified underlying assets amount.
     * @param assets The underlying assets amount to be converted into shares.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function convertToShares(uint256 assets)
        public
        pure
        override
        returns (uint256)
    {
        return assets;
    }

    /**
     * @dev See {IERC4626-convertToAssets}.
     * @notice The `convertToAssets` function is used to calculate underlying
     * assets amount received in exchange of the specified amount of shares.
     * @param shares The shares amount to be converted into underlying assets.
     * @return Amount of assets received in exchange of the specified shares
     * amount.
     */
    function convertToAssets(uint256 shares)
        public
        pure
        override
        returns (uint256)
    {
        return shares;
    }

    /**
     * @dev The `maxDeposit` function is used to calculate the maximum deposit.
     * @ param _ The address of the receiver.
     * @return Amount of the maximum underlying assets deposit amount.
     */
    function maxDeposit(address) public view override returns (uint256) {
        return _maxDeposit;
    }

    /**
     * @dev The `maxMint` function is used to calculate the maximum amount of
     * shares you can mint.
     * @ param _ The address of the receiver.
     * @return Amount of the maximum shares mintable for the specified address.
     */
    function maxMint(address) public view override returns (uint256) {
        return _maxDeposit;
    }

    /**
     * @dev The `maxWithdraw` function is used to calculate the maximum amount
     * of withdrawable underlying assets.
     * @return Amount of the maximum number of withdrawable underlying assets.
     */
    function maxWithdraw(address)
        public
        view
        override(ERC4626)
        returns (uint256)
    {
        return _maxWithdraw < totalAssets() ? _maxWithdraw : totalAssets();
    }

    /**
     * @dev The `maxRedemm` function is used to calculate the maximum amount of
     * redeemable shares.
     * @return Amount of the maximum number of redeemable shares.
     */
    function maxRedeem(address) public view override returns (uint256) {
        return _maxWithdraw < totalAssets() ? _maxWithdraw : totalAssets();
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
        override
        returns (uint256)
    {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        IERC20(asset()).safeTransferFrom(_msgSender(), receiver, assets);

        return assets;
    }

    /**
     * @dev The `mint` function is used to mint the specified amount of shares in
     * exchange of the corresponding assets amount from owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @return Amount of underlying assets deposited in exchange of the specified
     * amount of shares.
     */
    function mint(uint256 shares, address receiver)
        public
        override
        returns (uint256)
    {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        IERC20(asset()).safeTransferFrom(_msgSender(), receiver, shares);

        return shares;
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
        public
        override
        returns (uint256)
    {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        if (_maxWithdraw != type(uint256).max) _maxWithdraw -= assets;
        IERC20(asset()).safeTransferFrom(_treasuryWallet, receiver, assets);

        return assets;
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
        public
        override
        returns (uint256)
    {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        if (_maxWithdraw != type(uint256).max) _maxWithdraw -= shares;
        IERC20(asset()).safeTransferFrom(_treasuryWallet, receiver, shares);

        return shares;
    }

    /*
     ###################################################
      ampr CLAIMABLE UNDERLYING TOKEN RELATED FUNCTIONS
     ###################################################
    */

    /**
     * @dev The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * @notice The `claimToken` function is used to claim other tokens that have
     * been sent to the vault.
     * It can only be called by the owner of the contract (`onlyOwner` modifier).
     * @param token The IERC20 token to be claimed.
     */
    function claimToken(IERC20 token) external onlyOwner {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function setTreasuryWallet(address newTreasoryWallet) public onlyOwner {
        _treasuryWallet = newTreasoryWallet;
        // TODO emit event
    }

    function setMaxWithdraw(uint256 newMaxWithdraw) public onlyOwner {
        _maxWithdraw = newMaxWithdraw;
        // TODO emit event
    }

    // POTENTIALLY REMOVE THIS FUNCTION, IT SHOULD NOT BE NEEDED
    function setMaxDeposit(uint256 newMaxDeposit) public onlyOwner {
        _maxDeposit = newMaxDeposit;
        // TODO emit event
    }

    function setMinter(address newMinter) public onlyOwner {
        minter = newMinter;
        // TODO emit event
    }

    function mintFrom(uint256 amount, address receiver) external onlyMinter {
        mint(amount, receiver);
    }
}
