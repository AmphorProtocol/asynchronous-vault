// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./ZapperManagement.t.sol";

contract VaultZapperManagementWSTETH is VaultZapperManagement {
    constructor() VaultZapperManagement(_WSTETH) { }
}

contract VaultZapperManagementWBTC is VaultZapperManagement {
    constructor() VaultZapperManagement(_WBTC) { }
}

contract VaultZapperManagementUSDC is VaultZapperManagement {
    constructor() VaultZapperManagement(_USDC) { }
}
