// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../../src/VaultZapper.sol";
import "./OffChainCalls.t.sol";
import "../utils/SigUtils.sol";

contract VaultZapperOnlyAllowedVault is OffChainCalls {
    VaultZapper zapper;
    SigUtils internal sigUtils;
    uint256 userPrivateKey = _usersPk[0];
    address user = _users[0];

    using SafeERC20 for IERC20;

    function setUp() public {
        zapper = new VaultZapper();
        _setUpVaultAndZapper();
    }

    function test_fail_zapAndDepositNotAllowedVault() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultZapper.NotVault.selector, IERC4626(address(0))
            )
        );
        zapper.zapAndDeposit(_USDC, IERC4626(address(0)), _router, 1 * 1e18, "");
    }

    function test_fail_zapAndDepositWithPermitNotAllowedVault() public {
        vm.startPrank(user);
        vm.expectRevert();
        zapper.zapAndDepositWithPermit(
            _USDC,
            IERC4626(address(0)),
            _router,
            1 * 1e18,
            "",
            PermitParams({ r: "", s: "", v: 0, value: 0, deadline: 0 })
        );
    }

    function _setUpVaultAndZapper() public {
        // IERC4626(address(0)) = new
        // AmphorSyntheticVault(ERC20(address(asset)), "", "", 12);
        if (!zapper.authorizedRouters(_router)) {
            zapper.toggleRouterAuthorization(_router);
        }
    }
}
