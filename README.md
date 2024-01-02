# AsyncSynthVault

The AsyncSynthVault from Amphor is based on the ERC7540 standard.
We allow users to request deposits and withdrawals of their assets in an asynchrnous way. Those requests are validated at the end of each epoch.. We separate the assets hold by the contract with the assets used in the current epoch using the totalAssets variable.

###How does it work?
Accountability of pending deposits and withdrawals is ensured by the use of per epoch data. Though the various fonctions we store:

- The total amount of requested deposits and withdrawals for the current epoch using the `currentEpochPendingAssets` and `currentEpochPendingShares` variables. Those variables are reset at the end of each epoch.
- The total amount of assets and shares at the end of each epoch using the `epochs` mapping variable. This will be used to calculate the amount of shares/assets we owe to each user.
- The amount of requested deposits and withdrawals for each user using the `pendingDeposits` and `pendingWithdrawals` mapping variables.

<u>Important:</u> A user can only have one pending deposit and one pending withdrawal at a time. If a user requests a deposit or a withdrawal while he already has one pending, we will increase the amount of the current pending request. If the request concerns a different epoch, we will claim the previous pending request and create a new one for the new epoch.

Explanation of the vault's logic for a deposit request:

1. user requests a deposit using `requestDeposit(uint256 assets, address receiver, address owner)` function. The vault takes his assets but the users doesn't receive his shares yet.
2. We store the amount he deposited in his pendingDeposits balance, with the epochId associated. We also add the amount of assets he deposited to the `currentEpochPendingAssets` variable.
3. Owner calls the `nextEpoch(uint256 returnedUnderlyingAmount)` function. After the epoch end and strategy profits are realized, we store in `mapping(uint256 => Epoch) public epochs;` the amount of assets and shares for this particular epoch. Using those values we can compute the price per share and mint shares and add assets under management from the totalAsset variable. Using those same variables, users will be able to claim the right amount of shares anytime they want.

Note: since there are also pendingWithdrawals, we might burn shares and remove assets from the totalAssets variable. This will depend on the amount of pendingDeposit and pendingWithdrawal for the current epoch.

Other consideration:

- We might need to override the erc20 balanceOf function to take into account the pending deposits that can be claimed. This remark may also apply to other functions.

- why not use two others 1155 tokens for the pending shares/shares? Because we don't see a particular use case for the pending shares/assets being a proper token with all the associated functions. We will just use the vault to handle those pending shares/assets. Moreover making it another contract would add complexity and gas cost.

Upgreability:
Since we will have multiple vaults, we will base the upgradability of the vault on the beacon architecture. Like we will be able to update the implementation of all vault in one transaction. See https://docs.openzeppelin.com/contracts/3.x/api/proxy#BeaconProxy for more information.
