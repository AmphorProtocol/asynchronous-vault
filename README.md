## Asynchronous Amphor vaults

**This repository implements the ERC-7540 standard, it should so be considered as a draft since the standard is still in review state.**

### General overview:

- The vault accept two main states: open and closed. When the vault is open, users can deposit and withdraw their funds. When the vault is closed, users can do request of deposit or request of redeem.
- To help the management of the assets/shares waiting for a request and the ones that can be claimed, we used 2 extra contracts: the `PendingSilo` and the `ClaimableSilo`.
- Those requests are processed when the owner calls the functions `settle` or `open`. When this functions are called, the vault will change epoch, open and process the requests by moving funds between the silos and closed the vault again for the settle function.
- Each vault will be bootstrapped in order to avoid the inflation attack.
