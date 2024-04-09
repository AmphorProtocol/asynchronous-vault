// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../../src/VaultZapper.sol";
import "./OffChainCalls.t.sol";

abstract contract VaultZapperManagement is OffChainCalls {
    VaultZapper zapper;
    SigUtils internal sigUtils;
    uint256 userPrivateKey = _usersPk[0];
    address user = _users[0];
    ERC20 UNDERLYING;

    using SafeERC20 for IERC20;

    constructor(ERC20 _underlying) {
        UNDERLYING = ERC20(_underlying);
    }

    function setUp() public {
        zapper = new VaultZapper();
    }

    function test_removeVaultAuthorization() public {
        _setUpVaultAndZapper(UNDERLYING);
        uint256 allowanceBeforeDisabling =
            UNDERLYING.allowance(address(zapper), address(_vault));
        zapper.toggleVaultAuthorization(_vault);
        uint256 allowanceAfterDisabling =
            UNDERLYING.allowance(address(zapper), address(_vault));
        assertTrue(
            allowanceBeforeDisabling > 0 && allowanceAfterDisabling == 0,
            "Router disabling failed"
        );
    }

    function test_fail_removeVaultAuthorization_notOwner() public {
        _setUpVaultAndZapper(UNDERLYING);
        vm.startPrank(user);
        vm.expectRevert();
        zapper.toggleVaultAuthorization(_vault);
    }

    function test_withdrawToken() public {
        _setUpVaultAndZapper(UNDERLYING);
        uint256 amount = _USDT.balanceOf(address(this));
        deal(address(_USDT), address(zapper), 1000 * 1e6);
        zapper.withdrawToken(_USDT);
        uint256 amountAfter = _USDT.balanceOf(address(this));
        assertTrue(amount < amountAfter, "No dust collected");
    }

    function test_failWithdrawToken_notOwner() public {
        _setUpVaultAndZapper(UNDERLYING);
        vm.startPrank(user);
        vm.expectRevert();
        zapper.withdrawToken(_USDT);
    }

    function test_withdrawNativeToken() public {
        _setUpVaultAndZapper(UNDERLYING);
        uint256 amount = address(this).balance;
        deal(address(zapper), 1000 * 1e6);
        zapper.withdrawNativeToken();
        uint256 amountAfter = address(this).balance;
        assertTrue(amount < amountAfter, "No dust collected");
    }

    function test_fail_withdrawNativeToken_notOwner() public {
        _setUpVaultAndZapper(UNDERLYING);
        vm.startPrank(user);
        vm.expectRevert();
        zapper.withdrawNativeToken();
    }

    function test_pauseZapper() public {
        zapper.pause();
        assertTrue(zapper.paused(), "Zapper not paused");
    }

    function test_fail_pauseZapper_notOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        zapper.pause();
    }

    function test_fail_unpauseZapper() public {
        vm.expectRevert();
        zapper.unpause();
    }

    function test_fail_unpauseZapper_notOwner() public {
        zapper.pause();
        vm.startPrank(user);
        vm.expectRevert();
        zapper.unpause();
    }

    function test_unpauseZapper() public {
        zapper.pause();
        zapper.unpause();
        assertTrue(!zapper.paused(), "Zapper not unpaused");
    }

    function test_fail_approveTokenForRouter_notOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        zapper.approveTokenForRouter(UNDERLYING, _router);
    }

    function test_fail_toggleRouterAuthorization_notOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        zapper.toggleRouterAuthorization(_router);
    }

    function _setUpVaultAndZapper(IERC20 tokenOut) public {
        _vault = new AsyncVault();

        address usdc = vm.envAddress("USDC_MAINNET");
        address weth = vm.envAddress("WETH_MAINNET");
        address wbtc = vm.envAddress("WBTC_MAINNET");
        uint256 _bootstrapAmount;

        if (address(tokenOut) == usdc) {
            _bootstrapAmount = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_USDC");
        } else if (address(tokenOut) == weth) {
            _bootstrapAmount = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_WETH");
        } else if (address(tokenOut) == wbtc) {
            _bootstrapAmount = vm.envUint("BOOTSTRAP_AMOUNT_SYNTHETIC_WBTC");
        }

        _vault.initialize(
            10,
            _amphorLabs,
            _amphorLabs,
            ERC20(address(tokenOut)),
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
    }

    function _getTokenIn(Swap memory params) public {
        if (params.tokenIn != _ETH) {
            if (params.tokenInWhale == address(0)) {
                deal(address(params.tokenIn), address(this), 1000 * 1e18);
            } else {
                vm.prank(params.tokenInWhale);
                SafeERC20.safeTransfer(
                    params.tokenIn, address(this), 1000 * 1e18
                );
            }
            SafeERC20.forceApprove(
                IERC20(params.tokenIn), address(zapper), type(uint256).max
            );
        }
        deal(address(this), 1000 * 1e18);
    }

    receive() external payable { }
}
