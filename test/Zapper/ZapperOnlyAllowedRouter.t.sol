// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../../src/VaultZapper.sol";
import "./OffChainCalls.t.sol";
import "../utils/SigUtils.sol";

contract VaultZapperOnlyAllowedRouter is OffChainCalls {
    VaultZapper zapper;
    SigUtils internal sigUtils;
    uint256 userPrivateKey = _usersPk[0];
    address user = _users[0];

    using SafeERC20 for IERC20;

    function setUp() public {
        zapper = new VaultZapper();
        // _setUpVaultAndZapper();
    }

    function test_fail_zapAndDepositNotAllowedRouter() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultZapper.NotRouter.selector, IERC4626(address(0))
            )
        );
        zapper.zapAndDeposit(
            IERC20(_USDC), IERC4626(address(0)), address(0), 1 * 1e18, ""
        );
    }

    function test_fail_zapAndDepositWithPermitNotAllowedRouter() public {
        vm.startPrank(user);
        vm.expectRevert();
        zapper.zapAndDepositWithPermit(
            IERC20(_USDC),
            IERC4626(address(0)),
            address(0),
            1 * 1e18,
            "",
            PermitParams({ r: "", s: "", v: 0, value: 0, deadline: 0 })
        );
    }

    // function _setUpVaultAndZapper() public {
    //     // IERC4626(address(0)) = new
    // AmphorSyntheticVault(ERC20(address(asset)), "", "", 12);
    //     if (!zapper.authorizedRouters(address(0))) {
    //         zapper.toggleRouterAuthorization(address(0));
    //     }
    // }
}
