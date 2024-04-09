## Asynchronous Amphor vaults

**This repository implements the ERC-7540 standard, it should so be considered as a draft since the standard is still in review state.**

### General overview:

- The vault accept two main states: open and closed. When the vault is open, users can deposit and withdraw their funds. When the vault is closed, funds are taken awy from the vault (farming in some positions) and users can only do request of deposit or request of redeem.
- Those requests are processed when the owner of the vault calls the functions `settle` or `open`. When this functions are called, the vault will change epoch, open and process the requests by moving funds between the silos and closed the vault again for the settle function.
- To help the management of the assets/shares waiting for a request and the ones that can be claimed, we used 2 extra contracts: the `PendingSilo` and the `ClaimableSilo`. These contracts are in the AsyncSyncVault.sol file.
- Each vault will be bootstrapped in order to avoid the inflation attack.
- AsyncSynthVault inherit from the abstract SyncSynthVault contract and implement the asynchronous deposit and redeem functions.
- Zapper makes the swap of tokenA into tokenB and the deposit of this tokenB in a vault in one tx.


### Proxy pattern

The vaults uses a beacon proxy pattern. So in the setup functions of the tests,
we deploy them using the openzeppelin upgrades tools suits. You will have to run
tests using `forge clean && forge test --ffi`. If you want to run the tests without the proxy pattern and only on the implementation, set the PROXY variable in the .env to false, remove inside AsyncSynthVault and SyncSynthVault constructors the disableInitializers() call run the command `forge test`.

### Zapper

The zapper uses oneInch router v4. You will need to set the `ONEINCH_API_KEY` in the .env file to run the tests. You will likely get rate limited.


### previewSettle function overview:
Overview: What we do is simulating the actual deposit and redeem of the requests
By doing so we can answer the following question :
Are they more inflow or outflow from the vault ? 
And so if the owner must give back some assets to the vault (claimable silo to be precise) or if the vault will give assets to the owner fo the vault
     
uint256 sharesToMint = pendingDeposit.mulDiv(
            totalSupply + 1, _lastSavedBalance + 1, Math.Rounding.Floor
        );

        uint256 totalAssetsSnapshotForDeposit = _lastSavedBalance + 1;
        uint256 totalSupplySnapshotForDeposit = totalSupply + 1;

        uint256 assetsToWithdraw = pendingRedeem.mulDiv(
            _lastSavedBalance + pendingDeposit + 1,
            totalSupply + sharesToMint + 1,
            Math.Rounding.Floor
        );

 
Here you can see the deposit then redeem simulation that uses the same math as convertToShares and convertToAssets functions
In the redeem simulation we take into account the effect of the deposit on the totalSupply (+ sharesToMint)
And on totalAssets (+ pendingDeposit ).
We store the exact parameters of those computation in the total{Assets/Shares}Snapshot variables.
We store exactly those in order to use them later in the claim functions.

Finally 
```
if (pendingDeposit > assetsToWithdraw) {
            assetsToOwner = pendingDeposit - assetsToWithdraw;
        } else if (pendingDeposit < assetsToWithdraw) {
            assetsToVault = assetsToWithdraw - pendingDeposit;
        }
```

let us know if assets will go inside the vault or out of the vault 
Like that, as manager of the vault we can use the minimum amount of asset to settle everybody’s request 
