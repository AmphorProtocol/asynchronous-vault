## Asynchronous Amphor vaults

**This repository implements the ERC-7540 standard, it should so be considered as a draft since the standard is still in review state.**

### General overview:

- The vault accept two main states: open and closed. When the vault is open, users can deposit and withdraw their funds. When the vault is closed, users can do request of deposit or request of redeem.
- To help the management of the assets/shares waiting for a request and the ones that can be claimed, we used 2 extra contracts: the `PendingSilo` and the `ClaimableSilo`.
- Those requests are processed when the owner calls the functions `settle` or `open`. When this functions are called, the vault will change epoch, open and process the requests by moving funds between the silos and closed the vault again for the settle function.
- Each vault will be bootstrapped in order to avoid the inflation attack.
- AsyncSynthVault inherit from the abstract SyncSynthVault contract and implement the asynchronous deposit and redeem functions.

### Proxy

The vaults uses a beacon proxy pattern. So in the setup functions of the tests,
we deploy them using the openzeppelin upgrades tools suits. You will have to run
tests using `forge clean && forge test --ffi`. If you want to run the tests without the proxy pattern and only on the implementation, set the PROXY variable in the .env to false, run the command `forge test` and remove inside AsyncSynthVault and SyncSynthVault constructors the disableInitializers() call.

### Zapper

The zapper uses oneInch router v4. You will need to set the `ONEINCH_API_KEY` in the .env file to run the tests. You will likely get rate limited.
