//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./Global.t.sol";

abstract contract BaseProperties is GlobalTest {
    /**
     * @dev The `Math` lib is only used for `mulDiv` operations.
     */
    using Math for uint256;

    function test_decimals() public virtual {
        console.log("Vault decimals: %s", _vault.decimals());
        assertEq(_vault.decimals(), _vaultDecimals);
    }

    function test_asset() public virtual {
        console.log("Vault asset: %s", _vault.asset());
        assertEq(_vault.asset(), address(_underlying));
    }

    function test_totalAsset() public virtual {
        console.log("Vault total asset: %s", _vault.totalAssets());
        assertEq(_vault.totalAssets(), _bootstrapAmount);
    }

    // TODO: redo this test for each vault
    function test_convertToShares(uint256 assets) public virtual {
        vm.assume(
            assets
                <= (
                    type(uint256).max
                        / 10 ** (_vault.decimals() - _underlying.decimals())
                )
        );

        uint256 shares = _vault.convertToShares(assets);

        console.log("%s assets = %s shares", assets, shares);
    }

    // TODO: redo this test for each vault
    function test_convertToAssets(uint256 shares) public virtual {
        uint256 assets = _vault.convertToAssets(shares);

        console.log("%s shares = %s assets", shares, assets);
    }

    // TODO: redo this test for each vault
    function test_maxDeposit(address _address) public virtual {
        uint256 maxDeposit = _vault.maxDeposit(_address);

        console.log(
            "Max deposit of %s address is %s assets", _address, maxDeposit
        );
    }

    // TODO: redo this test for each vault
    function test_maxMint(address _address) public virtual {
        uint256 maxMint = _vault.maxMint(_address);

        console.log("Max mint of %s address is %s assets", _address, maxMint);
    }

    // TODO: redo this test for each vault
    function test_maxWithdraw(address _address) public virtual {
        uint256 maxWithdraw = _vault.maxWithdraw(_address);

        console.log(
            "Max withdraw of %s address is %s assets", _address, maxWithdraw
        );
    }

    // TODO: redo this test for each vault
    function test_maxRedeem(address _address) public virtual {
        uint256 maxRedeem = _vault.maxRedeem(_address);

        console.log(
            "Max redeem of %s address is %s assets", _address, maxRedeem
        );
    }

    // TODO: redo this test for each vault
    function test_previewDeposit(uint256 assets) public virtual {
        vm.assume(
            assets
                <= (
                    type(uint256).max
                        / 10 ** (_vault.decimals() - _underlying.decimals())
                )
        );

        uint256 shares = _vault.previewDeposit(assets);

        console.log("%s assets = %s shares", assets, shares);
    }

    // TODO: redo this test for each vault
    function test_previewMint(uint256 shares) public virtual {
        uint256 assets = _vault.previewMint(shares);

        console.log("%s shares = %s assets", shares, assets);
    }

    // TODO: redo this test for each vault
    function test_previewWithdraw(
        uint256 assets,
        uint256 vaultAssets,
        uint256 userSharesAmount
    )
        public
        virtual
    {
        vm.assume(vaultAssets < _underlying.totalSupply());
        vm.assume(userSharesAmount <= vaultAssets);
        vm.assume(assets <= vaultAssets);
        vm.assume(assets <= _vault.maxWithdraw(address(this)));

        console.log("vaultAssets", vaultAssets);

        deal(address(_vault), address(this), userSharesAmount);
        deal(address(_underlying), address(_vault), vaultAssets);

        _vault.approve(address(this), userSharesAmount);
        _vault.approve(address(_vault), vaultAssets);

        console.log("maxWithdraw %s", _vault.maxWithdraw(address(this)));
        console.log(
            "vaultopen value %s",
            _vault.convertToAssets(_vault.balanceOf(address(this)))
        );
        console.log(
            "vault assets value %s", _underlying.balanceOf(address(_vault))
        );
        console.log("vaultopen value %s", _vault.balanceOf(address(this)));

        uint256 shares = _vault.previewWithdraw(assets);

        console.log("%s assets = %s shares", assets, shares);
    }

    // TODO: redo this test for each vault
    function test_previewRedeem(uint256 shares) public virtual {
        uint256 assets = _vault.previewRedeem(shares);

        console.log("%s shares = %s assets", shares, assets);
    }

    // TODO: redo this test for each vault
    function test_deposit(uint256 assets, address receiver) public virtual {
        vm.assume(receiver != 0x0000000000000000000000000000000000000000);
        vm.assume(assets <= _vault.maxDeposit(receiver));
        vm.assume(
            assets
                <= (
                    type(uint256).max
                        / 10 ** (_vault.decimals() - _underlying.decimals())
                )
        );

        deal(address(_underlying), address(this), assets);
        _underlying.approve(address(_vault), assets);

        uint256 shares = _vault.deposit(assets, receiver);

        console.log("%s assets = %s shares", assets, shares);
    }

    // TODO: redo this test for each vault
    function test_mint(
        uint256 shares,
        address receiver,
        uint256 vaultAssets,
        uint256 sharesSupply
    )
        public
    {
        vm.assume(shares <= sharesSupply);
        vm.assume(shares <= _vault.maxMint(receiver));
        vm.assume(sharesSupply <= shares);
        vm.assume(vaultAssets <= _underlying.totalSupply());

        vm.assume(receiver != 0x0000000000000000000000000000000000000000);

        deal(address(_underlying), address(_vault), vaultAssets);
        deal(address(_vault), address(this), sharesSupply);

        console.log("balance", _underlying.balanceOf(address(this)));

        uint256 assets = _vault.previewMint(shares);
        deal(address(_underlying), address(this), assets);
        _underlying.approve(address(_vault), assets);

        assets = _vault.mint(0, receiver);
        console.log("%s previewed shares = %s previewed assets", shares, assets);

        console.log("%s actual shares = %s actual assets", shares, assets);
    }

    // TODO: redo this test for each vault
    function test_withdraw(
        uint256 userSharesAmount,
        uint256 vaultAssets,
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
    {
        vm.assume(owner != 0x0000000000000000000000000000000000000000);
        vm.assume(receiver != 0x0000000000000000000000000000000000000000);
        vm.assume(vaultAssets < _underlying.totalSupply());
        vm.assume(userSharesAmount >= vaultAssets);
        vm.assume(assets <= vaultAssets);
        vm.assume(assets <= _vault.maxWithdraw(owner));

        console.log("vaultAssets", vaultAssets);

        deal(address(_vault), address(owner), userSharesAmount);
        deal(address(_underlying), address(_vault), vaultAssets);

        address sender = address(this);

        vm.prank(address(owner));
        _vault.approve(address(sender), userSharesAmount);
        _vault.approve(address(_vault), vaultAssets);

        console.log("maxWithdraw %s", _vault.maxWithdraw(owner));
        console.log(
            "vaultopen value %s",
            _vault.convertToAssets(_vault.balanceOf(owner))
        );
        console.log(
            "vault assets value %s", _underlying.balanceOf(address(_vault))
        );
        console.log("vaultopen value %s", _vault.balanceOf(owner));

        vm.prank(address(owner));
        uint256 shares = _vault.withdraw(assets, receiver, owner);

        console.log("%s assets = %s shares", assets, shares);
    }

    // TODO: redo this test for each vault
    function test_redeem(
        uint256 shares,
        uint256 vaultAssets,
        address receiver,
        address owner
    )
        public
        virtual
    {
        vm.assume(owner != 0x0000000000000000000000000000000000000000);
        vm.assume(receiver != 0x0000000000000000000000000000000000000000);
        vm.assume(vaultAssets <= _underlying.totalSupply());
        vm.assume(shares <= _underlying.totalSupply());

        deal(address(_vault), address(owner), shares);
        deal(address(_underlying), address(_vault), vaultAssets);

        address sender = address(this);

        vm.prank(address(owner));
        _vault.approve(address(sender), shares);
        _vault.approve(address(_vault), shares);

        console.log("VALUE %s", _vault.maxRedeem(address(this)));

        uint256 assets = _vault.previewRedeem(shares);

        console.log("%s shares = %s assets", shares, assets);

        assets = _vault.redeem(shares, receiver, owner);
    }

    function test_name() public virtual {
        console.log("Vault name: %s", _vault.name());
        assertEq(_vault.name(), _vaultName);
    }

    function test_symbol() public virtual {
        console.log("Vault symbol: %s", _vault.symbol());
        assertEq(_vault.symbol(), _vaultSymbol);
    }

    function test_totalSupply() public virtual {
        console.log("Vault totalSupply: %s", _vault.totalSupply());
        assertEq(_vault.totalSupply(), _initialMintAmount);
    }

    function test_balanceOf() public virtual {
        console.log("This balance: %s", _vault.balanceOf(address(this)));
        console.log("_initialMintAmount : %s", _initialMintAmount);
        assertEq(_vault.balanceOf(address(this)), _initialMintAmount);
    }
}
