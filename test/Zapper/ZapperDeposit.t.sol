// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../../src/VaultZapper.sol";
import { AsyncVault } from "../../src/AsyncVault.sol";
import "./OffChainCalls.t.sol";

contract VaultZapperDeposit is OffChainCalls {
    VaultZapper zapper;
    SigUtils internal sigUtils;
    uint256 userPrivateKey = _usersPk[0];
    address user = _users[0];

    using SafeERC20 for IERC20;

    function setUp() public {
        zapper = new VaultZapper();
    }

    //// test_zapAndDeposit ////
    function test_zapAndDepositUsdcWSTETH() public {
        Swap memory usdcToWstEth =
            Swap(_router, _USDC, _WSTETH, 1500 * 1e6, 1, address(0), 20);
        _setUpVaultAndZapper(_WSTETH);
        _zapAndDeposit(usdcToWstEth, _vault);
    }

    function test_zapAndDepositUsdcWBTC() public {
        Swap memory usdcToWbtc =
            Swap(_router, _USDC, _WBTC, 1500 * 1e6, 1, address(0), 20);
        _setUpVaultAndZapper(_WBTC);
        _zapAndDeposit(usdcToWbtc, _vault);
    }

    function test_zapAndDepositDAIUSDC() public {
        Swap memory daiToUsdc =
            Swap(_router, _DAI, _USDC, 150 * 1e6, 1, address(0), 20);
        _setUpVaultAndZapper(_USDC);
        _zapAndDeposit(daiToUsdc, _vault);
    }

    //// test_failZapAndDepositUnknownReason ////
    function test_failZapAndDepositUsdcWSTETHUnknownReason() public {
        Swap memory usdcToWstEth =
            Swap(_router, _USDC, _WSTETH, 150_000_000 * 1e6, 1, address(0), 0);
        _setUpVaultAndZapper(_WSTETH);
        _failZapAndDeposit(usdcToWstEth, 150_000_000 * 1e6);
    }

    function test_failZapAndDepositUsdcWBTCUnknownReason() public {
        Swap memory usdcToWbtc =
            Swap(_router, _USDC, _WBTC, 150_000_000 * 1e6, 1, address(0), 0);
        _setUpVaultAndZapper(_WBTC);
        _failZapAndDeposit(usdcToWbtc, 150_000_000 * 1e6);
    }

    function test_failZapAndDepositDaiUsdcUnknownReason() public {
        Swap memory daiToUsdc =
            Swap(_router, _DAI, _USDC, 150_000_000 * 1e45, 1, address(0), 0);
        _setUpVaultAndZapper(_USDC);
        _failZapAndDeposit(daiToUsdc, 150 * 1e45);
    }

    //// test_failZapAndDepositERC20PlusEth ////
    function test_failZapAndDepositERC20PlusEthWSTETH() public {
        Swap memory usdcToWstEth =
            Swap(_router, _USDC, _WSTETH, 1500 * 1e6, 1, address(0), 30);
        _setUpVaultAndZapper(_WSTETH);
        _failZapAndDeposit_eth(usdcToWstEth, 1500 * 1e6);
    }

    function test_failZapAndDepositERC20PlusEthUSDC() public {
        Swap memory usdcToWbtc =
            Swap(_router, _USDC, _WBTC, 1500 * 1e6, 1, address(0), 30);
        _setUpVaultAndZapper(_WBTC);
        _failZapAndDeposit_eth(usdcToWbtc, 1500 * 1e6);
    }

    function test_failZapAndDepositERC20PlusEthWBTC() public {
        Swap memory daiToUsdc =
            Swap(_router, _DAI, _USDC, 1500 * 1e6, 1, address(0), 30);
        _setUpVaultAndZapper(_USDC);
        _failZapAndDeposit_eth(daiToUsdc, 1500 * 1e6);
    }

    //// test_inconsistantZapAndDeposit ////
    function test_inconsistantZapAndDepositUsdcWSTETH() public {
        Swap memory usdcToWstEth = Swap(
            _router,
            IERC20(_USDC),
            IERC20(_WSTETH),
            1000 * 1e6,
            1,
            address(0),
            20
        );
        _setUpVaultAndZapper(_WSTETH);
        _failZapAndDeposit(usdcToWstEth, 1500 * 1e6);
    }

    function test_inconsistantZapAndDepositUsdcWBTC() public {
        Swap memory usdcToWbtc = Swap(
            _router, IERC20(_USDC), IERC20(_WBTC), 1000 * 1e6, 1, address(0), 20
        );
        _setUpVaultAndZapper(_WBTC);
        _failZapAndDeposit(usdcToWbtc, 1500 * 1e6);
    }

    function test_inconsistantZapAndDepositDaiUSDC() public {
        Swap memory daiToUsdc = Swap(
            _router, IERC20(_DAI), IERC20(_USDC), 1000 * 1e6, 1, address(0), 20
        );
        _setUpVaultAndZapper(_USDC);
        _failZapAndDeposit(daiToUsdc, 1500 * 1e6);
    }

    //// test_failZapAndDeposit ////
    function test_failZapAndDepositUsdcWSTETH() public {
        Swap memory usdcToWstEth = Swap(
            _router,
            IERC20(_USDC),
            IERC20(_WSTETH),
            1000 * 1e6,
            type(uint256).max,
            address(0),
            20
        );
        _setUpVaultAndZapper(_WSTETH);
        _failZapAndDeposit(usdcToWstEth, 1500 * 1e6);
    }

    function test_failZapAndDepositUsdcWBTC() public {
        Swap memory usdcToWbtc = Swap(
            _router,
            IERC20(_USDC),
            IERC20(_WBTC),
            1000 * 1e6,
            type(uint256).max,
            address(0),
            20
        );
        _setUpVaultAndZapper(_WBTC);
        _failZapAndDeposit(usdcToWbtc, 1500 * 1e6);
    }

    function test_failZapAndDepositDaiUSDC() public {
        Swap memory daiToUsdc = Swap(
            _router,
            IERC20(_DAI),
            IERC20(_USDC),
            1000 * 1e6,
            type(uint256).max,
            address(0),
            20
        );
        _setUpVaultAndZapper(_USDC);
        _failZapAndDeposit(daiToUsdc, 1500 * 1e6);
    }

    //// test_zapAndDepositEth ////
    function test_zapAndDepositEthWSTETH() public {
        Swap memory ethToWstEth =
            Swap(_router, _ETH, _WSTETH, 1e18, 1, address(0), 200);
        _zapAndDeposit_eth(ethToWstEth);
    }

    function test_zapAndDepositEthWBTC() public {
        Swap memory ethToWbtc =
            Swap(_router, _ETH, _WBTC, 1e18, 1, address(0), 200);
        _setUpVaultAndZapper(_WBTC);
        _zapAndDeposit_eth(ethToWbtc);
    }

    function test_zapAndDepositEthUSDC() public {
        Swap memory ethToUsdc =
            Swap(_router, _ETH, _USDC, 1e18, 1, address(0), 200);
        _setUpVaultAndZapper(_USDC);
        _zapAndDeposit_eth(ethToUsdc);
    }

    //// test_inconsistantZapAndDepositEth ////
    function test_inconsistantZapAndDepositEthWSTETH() public {
        Swap memory ethToWstEth =
            Swap(_router, _ETH, _WSTETH, 1e18, 1, address(0), 10_000);
        _setUpVaultAndZapper(_WSTETH);
        _failZapAndDeposit_eth(ethToWstEth, 2e18);
    }

    function test_inconsistantZapAndDepositEthWBTC() public {
        Swap memory ethToWbtc =
            Swap(_router, _ETH, _WBTC, 1e18, 1, address(0), 10_000);
        _setUpVaultAndZapper(_WBTC);
        _failZapAndDeposit_eth(ethToWbtc, 2e18);
    }

    function test_inconsistantZapAndDepositEthUSDC() public {
        Swap memory ethToUsdc =
            Swap(_router, _ETH, _USDC, 1e18, 1, address(0), 10_000);
        _setUpVaultAndZapper(_USDC);
        _failZapAndDeposit_eth(ethToUsdc, 2e18);
    }

    //// test_inconsistantZapAndDepositEthNullShares ////
    function test_inconsistantZapAndDepositEthWSTETHNullShares() public {
        Swap memory ethToWstEth = Swap(
            _router, IERC20(_ETH), IERC20(_WSTETH), 1e18, 0, address(0), 10_000
        );
        _failZapAndDeposit_eth(ethToWstEth, 2e18);
    }

    function test_inconsistantZapAndDepositEthWBTCNullShares() public {
        Swap memory ethToWbtc = Swap(
            _router, IERC20(_ETH), IERC20(_WBTC), 1e18, 0, address(0), 10_000
        );
        _failZapAndDeposit_eth(ethToWbtc, 2e18);
    }

    function test_inconsistantZapAndDepositEthUSDCNullShares() public {
        Swap memory ethToUSDC = Swap(
            _router, IERC20(_ETH), IERC20(_USDC), 1e18, 0, address(0), 10_000
        );
        _failZapAndDeposit_eth(ethToUSDC, 2e18);
    }

    //// test_inconsistantZapAndDepositErc20NullShares ////
    function test_inconsistantZapAndDepositUsdcWSTETHNullShares() public {
        Swap memory usdcToWstEth =
            Swap(_router, _USDC, _WSTETH, 1000 * 1e6, 0, address(0), 20);
        _setUpVaultAndZapper(_WSTETH);
        _failZapAndDeposit(usdcToWstEth, 1500 * 1e6);
    }

    function test_inconsistantZapAndDepositUsdcWBTCNullShares() public {
        Swap memory usdcToWbtc =
            Swap(_router, _USDC, _WBTC, 1000 * 1e6, 0, address(0), 20);
        _setUpVaultAndZapper(_WBTC);
        _failZapAndDeposit(usdcToWbtc, 1500 * 1e6);
    }

    function test_inconsistantZapAndDepositDaiUSDCNullShares() public {
        Swap memory daiToUsdc = Swap(
            _router, IERC20(_DAI), IERC20(_USDC), 1000 * 1e18, 0, address(0), 20
        );
        _setUpVaultAndZapper(_USDC);
        _failZapAndDeposit(daiToUsdc, 1500 * 1e6);
    }

    // UTILITY FUNCTIONS

    function _zapAndDeposit(Swap memory params, IERC4626 vault) public {
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params);
        uint256 beforeDep = vault.balanceOf(address(this));
        if (keccak256(swapData) == keccak256(hex"")) vm.expectRevert();
        zapper.zapAndDeposit(
            params.tokenIn, vault, params.router, params.amount, swapData
        );
        uint256 afterDep = vault.balanceOf(address(this));
        if (keccak256(swapData) != keccak256(hex"")) {
            assertTrue(afterDep > beforeDep, "Deposit failed");
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

    function _zapAndDeposit_eth(Swap memory params) public {
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _getTokenIn(params);

        _setUpVaultAndZapper(params.tokenOut);
        uint256 beforeDep = _vault.balanceOf(address(this));
        if (keccak256(swapData) == keccak256(hex"")) vm.expectRevert();
        zapper.zapAndDeposit{ value: params.amount }(
            params.tokenIn, _vault, params.router, params.amount, swapData
        );
        uint256 afterDep = _vault.balanceOf(address(this));
        if (keccak256(swapData) != keccak256(hex"")) {
            assertTrue(afterDep > beforeDep, "Deposit failed");
        }
    }

    function _failZapAndDeposit_eth(
        Swap memory params,
        uint256 amount
    )
        public
    {
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params);
        vm.expectRevert();
        zapper.zapAndDeposit{ value: amount }(
            params.tokenIn, _vault, params.router, params.amount, swapData
        );
    }

    function test_fail_zapAndDeposit_NotEnoughShares() public {
        Swap memory params = Swap(
            _router,
            IERC20(_USDC),
            IERC20(_WSTETH),
            1500 * 1e6,
            type(uint256).max,
            vm.envAddress("USDC_WHALE"),
            100
        );
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params);
        uint256 beforeDepTokenIn =
            (IERC20(address(params.tokenIn)).balanceOf(address(this)));

        uint256 value = params.tokenIn == IERC20(_ETH) ? params.amount : 0;
        vm.expectRevert();
        zapper.zapAndDeposit{ value: value }(
            params.tokenIn, _vault, params.router, params.amount, swapData
        );
        uint256 afterDepTokenIn =
            (IERC20(address(params.tokenIn)).balanceOf(address(this)));
        assertTrue(afterDepTokenIn == beforeDepTokenIn, "Deposit failed");
    }

    function test_fail_zapAndDeposit_RouterFails() public {
        Swap memory params = Swap(
            _router,
            IERC20(_USDC),
            IERC20(_WSTETH),
            1500 * 1e6,
            type(uint256).max,
            vm.envAddress("USDC_WHALE"),
            100
        );
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        if (keccak256(swapData) != keccak256(hex"")) swapData[0] = hex"00";
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params);
        uint256 beforeDepTokenIn =
            (IERC20(address(params.tokenIn)).balanceOf(address(this)));

        uint256 value = params.tokenIn == IERC20(_ETH) ? params.amount : 0;
        vm.expectRevert();
        zapper.zapAndDeposit{ value: value }(
            params.tokenIn, _vault, params.router, params.amount, swapData
        );
        uint256 afterDepTokenIn =
            (IERC20(address(params.tokenIn)).balanceOf(address(this)));
        assertTrue(afterDepTokenIn == beforeDepTokenIn, "Deposit failed");
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
