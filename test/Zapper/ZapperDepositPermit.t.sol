// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../../src/VaultZapper.sol";
import "../utils/SigUtils.sol";
import "./OffChainCalls.t.sol";

contract SyntheticZapperPermitTest is OffChainCalls {
    VaultZapper zapper;
    SigUtils internal sigUtils;
    uint256 userPrivateKey = 0xA11CE;
    address user = vm.addr(userPrivateKey);

    function setUp() public {
        zapper = new VaultZapper();
    }

    function test_zapAndDepositPermit_USDCWSTETH() public {
        _setUpVaultAndZapper(_WSTETH);
        _zapAndDepositPermit(
            Swap(
                _router,
                IERC20(_USDC),
                IERC20(_WSTETH),
                15 * 1e6,
                0,
                address(0),
                10_000
            )
        );
    }

    function test_zapAndDepositPermit_DAIUSDC() public {
        _setUpVaultAndZapper(_USDC);
        _zapAndDepositPermit(
            Swap(_router, _DAI, _USDC, 15 * 1e6, 0, address(0), 10_000)
        );
    }

    function test_zapAndDepositPermit_USDCWBTC() public {
        _setUpVaultAndZapper(_WBTC);
        _zapAndDepositPermit(
            Swap(_router, _USDC, _WBTC, 15 * 1e6, 0, address(0), 10_000)
        );
    }

    function _zapAndDepositPermit(Swap memory params) public {
        ERC20Permit token = ERC20Permit(address(params.tokenIn));
        sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        bytes memory swapData =
            _getSwapData(address(zapper), address(zapper), params);
        _setUpVaultAndZapper(params.tokenOut);
        _getTokenIn(params, user);
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: user,
            spender: address(zapper),
            value: params.amount,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            address(zapper), permit.value, permit.nonce, permit.deadline
        );

        PermitParams memory permitParams = PermitParams({
            value: permit.value,
            deadline: block.timestamp + 1 days,
            v: v,
            r: r,
            s: s
        });

        // execPermit(user, address(zapper), address(params.tokenIn),
        // permitParams);

        uint256 beforeDep = (IERC20(address(_vault)).balanceOf(user));

        vm.prank(user);

        if (keccak256(swapData) == keccak256(hex"")) vm.expectRevert();
        zapper.zapAndDepositWithPermit(
            params.tokenIn,
            _vault,
            params.router,
            params.amount,
            swapData,
            permitParams
        );

        uint256 afterDep = (IERC20(address(_vault)).balanceOf(user));
        console.log("Shares balance after deposit", afterDep);

        if (keccak256(swapData) != keccak256(hex"")) {
            assertTrue(afterDep > beforeDep, "Deposit permit failed");
        }
    }

    function execPermit(
        address owner,
        address spender,
        address token,
        PermitParams memory permitParams
    )
        internal
    {
        ERC20Permit(address(token)).permit(
            owner,
            spender,
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s
        );
    }

    function _signPermit(
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
            owner: user,
            spender: _spender,
            value: _value,
            nonce: _nonce,
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (v, r, s) = vm.sign(userPrivateKey, digest);
        return (v, r, s);
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

    function _getTokenIn(Swap memory params, address receiver) public {
        if (params.tokenIn != _ETH) {
            if (params.tokenInWhale == address(0)) {
                deal(address(params.tokenIn), receiver, 1000 * 1e18);
            } else {
                vm.prank(params.tokenInWhale);
                SafeERC20.safeTransfer(params.tokenIn, receiver, 1000 * 1e18);
            }
            SafeERC20.forceApprove(
                IERC20(params.tokenIn), address(zapper), type(uint256).max
            );
        }
        deal(receiver, 1000 * 1e18);
    }
}
