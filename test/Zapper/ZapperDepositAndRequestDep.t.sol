// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../../src/VaultZapper.sol";
import { AsyncVault } from "../../src/AsyncVault.sol";
import "./OffChainCalls.t.sol";

contract VaultZapperRequestDeposit is OffChainCalls {
    VaultZapper zapper;
    SigUtils internal sigUtils;
    uint256 userPrivateKey = _usersPk[0];
    address user = _users[0];

    using SafeERC20 for IERC20;

    function setUp() public {
        zapper = new VaultZapper();
    }

    //// test_zapAndDeposit ////
    function test_zapAndRequestDepositUsdcWSTETH() public {
        Swap memory usdcToWstEth =
            Swap(_router, _USDC, _WSTETH, 1500 * 1e6, 1, address(0), 20);
        _dealAsset(address(_WSTETH), address(this), 100 * 10e18);
        _setUpVaultAndZapper(_WSTETH);
        _WSTETH.approve(address(_vault), type(uint256).max);
        _vault.deposit(10 * 10e18, address(this));

        vm.prank(_amphorLabs);
        _vault.close();
        _zapAndRequestDeposit(usdcToWstEth, _vault);
    }

    function test_zapAndClaimAndRequestDepositUsdcWSTETH() public {
        Swap memory usdcToWstEth =
            Swap(_router, _USDC, _WSTETH, 15 * 1e6, 1, address(0), 20);
        _dealAsset(address(_WSTETH), address(this), 100 * 10e18);
        _setUpVaultAndZapper(_WSTETH);
        _WSTETH.approve(address(_vault), type(uint256).max);
        _vault.deposit(10 * 10e18, address(this));

        vm.prank(_amphorLabs);
        _vault.close();
        _zapAndRequestDeposit(usdcToWstEth, _vault);

        uint256 lastSavedBalance = _vault.totalAssets();

        vm.startPrank(_amphorLabs);
        _WSTETH.approve(address(_vault), type(uint256).max);
        _vault.open(lastSavedBalance);
        _vault.close();
        vm.stopPrank();
        _zapAndClaimAndRequestDeposit(usdcToWstEth, _vault);
    }

    function test_zapClaimAndRequestDepositPermit_USDCWSTETH() public {
        _dealAsset(address(_WSTETH), address(this), 1000 * 10e18);
        _dealAsset(address(_WSTETH), user, 1000 * 10e18);
        _dealAsset(address(_USDC), user, 100 * 10e6);
        _setUpVaultAndZapper(_WSTETH);
        _WSTETH.approve(address(_vault), type(uint256).max);
        _vault.deposit(10 * 10e18, address(this));

        vm.prank(_amphorLabs);
        _vault.close();
        vm.startPrank(user);
        _WSTETH.approve(address(_vault), type(uint256).max);
        _vault.requestDeposit(10 * 10e18, user, user, "");
        vm.stopPrank();

        uint256 lastSavedBalance = _vault.totalAssets();

        vm.startPrank(_amphorLabs);
        _WSTETH.approve(address(_vault), type(uint256).max);
        _vault.open(lastSavedBalance);
        _vault.close();
        vm.stopPrank();
        _zapAndClaimAndRequestDepositPermit(
            Swap(_router, _USDC, _WSTETH, 15 * 1e6, 1, address(0), 20)
        );
    }

    // UTILITY FUNCTIONS

    function _zapAndRequestDeposit(
        Swap memory params,
        AsyncVault vault
    )
        public
    {
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _getTokenIn(params);
        uint256 beforeDep = vault.pendingDepositRequest(address(this));
        if (keccak256(swapData) == keccak256(hex"")) vm.expectRevert();
        zapper.zapAndRequestDeposit(
            params.tokenIn, vault, params.router, params.amount, swapData, ""
        );
        uint256 afterDep = vault.pendingDepositRequest(address(this));
        if (keccak256(swapData) != keccak256(hex"")) {
            assertTrue(afterDep > beforeDep, "request Deposit failed");
        }
    }

    function _zapAndClaimAndRequestDeposit(
        Swap memory params,
        AsyncVault vault
    )
        public
    {
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params);
        uint256 beforeDep = vault.pendingDepositRequest(address(this));
        uint256 beforeDepShares = vault.balanceOf(address(this));
        if (keccak256(swapData) == keccak256(hex"")) vm.expectRevert();
        zapper.zapAndRequestDeposit(
            params.tokenIn, vault, params.router, params.amount, swapData, ""
        );
        uint256 afterDep = vault.pendingDepositRequest(address(this));
        uint256 afterDepShares = vault.balanceOf(address(this));
        if (keccak256(swapData) != keccak256(hex"")) {
            assertTrue(afterDep > beforeDep, "request Deposit failed");
            assertTrue(
                afterDepShares > beforeDepShares, "request Deposit failed"
            );
        }
    }

    function _failZapAndDeposit(Swap memory params, uint256 amount) public {
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params);
        vm.expectRevert();
        zapper.zapAndDeposit(
            params.tokenIn, _vault, params.router, amount, swapData
        );
    }

    function _zapAndClaimAndRequestDepositPermit(Swap memory params) public {
        ERC20Permit token = ERC20Permit(address(params.tokenIn));
        sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: user,
            spender: address(zapper),
            value: params.amount,
            nonce: token.nonces(user),
            deadline: block.timestamp + 1 days
        });
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            user, permit.spender, permit.value, permit.nonce, permit.deadline
        );

        PermitParams memory permitParams = PermitParams({
            value: permit.value,
            deadline: block.timestamp + 1 days,
            v: v,
            r: r,
            s: s
        });

        uint256 beforeDep = (IERC20(address(_vault)).balanceOf(user));
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        vm.prank(user);
        zapper.zapAndRequestDepositWithPermit(
            params.tokenIn,
            _vault,
            params.router,
            params.amount,
            swapData,
            permitParams,
            ""
        );

        uint256 afterDep = (IERC20(address(_vault)).balanceOf(user));

        if (keccak256(swapData) != keccak256(hex"")) {
            assertTrue(afterDep > beforeDep, "Deposit permit failed");
        }
    }

    function _signPermit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 deadline
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: _owner,
            spender: _spender,
            value: _value,
            nonce: _nonce,
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (v, r, s) = vm.sign(userPrivateKey, digest);
        return (v, r, s);
    }

    function _setUpVaultAndZapper(IERC20 asset) public {
        _vault = new AsyncVault();

        address usdc = vm.envAddress("USDC_MAINNET");
        address weth = vm.envAddress("WETH_MAINNET");
        address wbtc = vm.envAddress("WBTC_MAINNET");
        uint256 _bootstrapAmount;

        if (address(asset) == usdc) {
            _bootstrapAmount = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_USDC");
        } else if (address(asset) == weth) {
            _bootstrapAmount = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_WETH");
        } else if (address(asset) == wbtc) {
            _bootstrapAmount = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_WBTC");
        }

        _vault.initialize(
            10,
            _amphorLabs,
            _amphorLabs,
            ERC20(address(asset)),
            _bootstrapAmount,
            "",
            ""
        );

        if (!zapper.authorizedRouters(_router)) {
            zapper.toggleRouterAuthorization(_router);
        }
        if (!zapper.authorizedVaults(_vault)) {
            zapper.toggleVaultAuthorization(_vault);
        }
        zapper.approveTokenForRouter(IERC20(_vault.asset()), _router);
    }

    function _getTokenIn(Swap memory params) public {
        if (address(params.tokenIn) == address(_USDC)) {
            params.tokenInWhale = vm.envAddress("USDC_WHALE");
        }
        if (params.tokenIn != _ETH) {
            if (params.tokenInWhale == address(0)) {
                _dealAsset(address(params.tokenIn), address(this), 10e18);
            } else {
                vm.prank(params.tokenInWhale);
                SafeERC20.safeTransfer(
                    params.tokenIn, address(this), 10_000 * 1e6
                );
            }
            SafeERC20.forceApprove(
                IERC20(params.tokenIn), address(zapper), type(uint256).max
            );
        }

        deal(address(this), 100 * 10e18);
    }
}
