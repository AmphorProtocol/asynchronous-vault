# AsyncSynthVault

## Introduction

The AsyncSynthVault from Amphor is based on the ERC7540 standard.
We allow users to request deposits and withdrawals of their assets in an asynchronous way. Our vault integrates a system of epoch. At the beginning of an epoch, funds are withdrawns from the contract to work in an offchain strategy. At the end of an epoch they come back plus some profits. Those requests are always associated with an epoch and they are accepted at its end. The vault will be also upgradable. To compute a price of pending shares, we will use historic data from previous epochs and compute using the same formula as in a typical ERC4626 vault.

###How does it work?

####Main data structures:
Accountability of pending deposits and withdrawals is ensured by the use of historic epoch data:

- The historic amount of assets and shares at the end of each epoch is stored in `mapping(uint256 => Epoch) public epochs`. Where epoch is a struct made of the amount of assets and the supply at the end of the epoch.

  ```
  struct Epoch {
      uint256 totalAssets;
      uint256 supply;
  }
  ```

- The balance value of pending deposits and withdrawals for each user using the `pendingDeposits` and `pendingRedeems` mapping variables. A pending deposit is a struct made of the epochId and the amount of assets. A pending withdrawal is a struct made of the epochId and the amount of shares.

  ```
  struct PendingDeposit {
    uint256 epochId;
    uint256 assets;
  }
  ```

- The total amount of requested deposits and withdrawals for the current epoch using the `currentEpochPendingAssets` and `currentEpochPendingShares` variables. Those variables are reset at the end of each epoch.
  comment: it seems possible to compute those variables in the `nextEpoch` function. It could save storage write operations.

<u>Important:</u> To simplify the smart contract and avoid loops, a choice was made to limit to one the number of pending deposit/withdrawals a user can make at a time. If a user requests a deposit or a withdrawal while he already has one in the current epoch, we will increase the amount of the current pending request. If the request concerns a different epoch, we will claim the previous pending request and create a new one for the current epoch.

#####Flow of a deposit request:

1. user requests a deposit using `requestDeposit(uint256 assets, address receiver, address owner)` function. The vault takes his assets but the users doesn't receive his shares yet.
2. We store the amount he deposited and the `epochId` in his `pendingDeposits` struct. We also add the amount of assets he deposited to the `currentEpochPendingAssets` variable.
3. Owner calls the `function nextEpoch(uint256 returnedUnderlyingAmount)`. After the epoch end, and strategy profits are realized, we store in the `mapping(uint256 => Epoch) public epochs` the total amount of assets and shares for this particular epoch.
   We now mint the necessary amount of new shares.
   We can do it using the `currentEpochPendingAssets`, `currentEpochPendingShares` variables and the `epochs` mapping. After we can increment the epochId, reset the `currentEpochPendingAssets` and `currentEpochPendingShares` variables and start a new epoch.

4. Now users can claim their shares using the `deposit` functions thanks to the `epochs`
   mapping and their pendingDeposits data.

Note: since there are also pendingWithdrawals, we might burn shares and remove assets from the totalAssets variable. This will depend on the amount of pendingDeposit and pendingWithdrawal for the current epoch.

##Other considerations:

- Upgreability:
  Since we will have multiple async vaults, we will base the upgradability on the beacon proxy system. Like that we will be able to update the implementation of all vaults in one transaction. See https://docs.openzeppelin.com/contracts/3.x/api/proxy#BeaconProxy for more information.

- We might need to override the erc20 balanceOf function to take into account the pending deposits that can be claimed. This remark may also apply to other functions.

Why not use two others external 1155/6909 smartcontract tokens for the pending shares/assets?

- <b>no express need to make the pendingShares and pendingAssets tokens.</b>
- add complexity and gas cost.
- <b>makes the upgradability of the vault more complex.</b>
- may increase audits cost.

In summary with a single smart contract, we have a solution that is easy to understand, easy to upgrade, easy to audit and gas efficient.
