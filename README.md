## Asynchronous Amphor vaults

*This repository implements the ERC-7540, it should so be considered as a draft since the standard is still in review state.*

### Problem solved:  
- The Amphor strategy currently works with epochs, so deposits and withdrawals are only active between these. Because of this strategy system, we are forced to not farm during a certain amount of time in order to let users deposit between periods. Also, this is decreasing the user experience because they cannot deposit or withdraw when they want but instead need to be here at the right moment.
- Thank to the deposit and withdraw request system we will be able to bypass this.

### Two contracts architecture vs One contract

- In order to implement the 7540 where the request ids are discriminated by epoch and not by user (in order to treat users requests globally), we need to have one balance of deposits/request per epoch and per user and one total supply per epoch.
- The deposits requests and withdrawals requests are each working like a multi-token interest vault. The share is the request token receipt and the underlying can be the main vault (the erc7540 one) underlying (in deposit requests case) or shares (in redeem requests case).
- We see two possible implementations of this system:
    - The first one is to add all this properties into the main vault. And keep this logic internal.
    - The second one is to use a multi-token standard such as 1155 or 6909 to create a pending request receipt token implementable for deposit and withdraw requests.

### This branch vision about this
- Into this branch, I have chosen to implement the base vault with the two contracts architecture.
The main vault is `SynthVault.sol`, and the pending requests (deposit or withdrawals) multi-token is `SynthVaultRequestReceipt.sol`. The `SynthVaultPermit.sol` file is just adding the permit feature for some specific strategy underlying tokens (such as `USDC`).
- The reasons why I think it might be a better architecture are the followings:
    - Separate business logic between the main vault and the receipts tokens. I think it over-complexifies the main vault contract to handle the accountability of the vault shares and also the deposit && withdraw requests into the same place. It makes the code more confusing, especially for devs used to deal with 4626 vaults.
    - Into the eip-7540, it is suggested that we shouldn't inherit from erc1155 because it `would create too much interface bloat`. 
    Based on this, I asked into the [`4626 Alliance Community` Telegram group](https://t.me/erc4626alliance) a question about what architecture we should use and _Joey Santoro_, the main ERC-7540 contributor implied that the right way of implemanting his standard should be to use an external contract token. However since it is not clearly specified into the eip, I could simply be falling for an argument from authority :)
    - I think that it is a smart-contract development good practice to apply the standard that can match our piece of code for future composability while keeping an acceptable YAGNI balance.
    - We plan to have upgradable vaults and to do so we will use proxy (we plan to use a beacon proxy but we are open to others suggestions).  
    This means that we will have 2 proxy instead of one (one for the main vault and one for the request receipt) so it will split our codebase, and will add a granularity level. I think it is better to have a liter code to upgrade each time we need to make a change.  
    Having this layer of granularity will also allow us to have a better composability since it will allow us to add features on the receipt tokens without touching the main vault.  
    If we start on the one contract infrastructure, I'm afraid it will complicate things since we will already implement multiple interfaces, and we will not be able to easily switch to the 2 contracts infrastructure because we would need to transfer the storage of the user requests balances.  
    However, in the case we modify both the codebase of the request receipts and the main vault, it will require us to deploy 3 new contracts instead of 1. I still think in most of the case this will not happen (or less and less over time).
    - I don't think I need to dwell too much on the composability part. However, an example of what we'll potentially do with deposit/withdrawal request receipts is to lock request receipts into a contract in order to start farming earlier and in order to incentivize new deposits (we would therefor either make the users farm our token either we will keep a very small part of our yield to bribes new entrants).  
    However, it is entirely possible to create a contract that will receive the underlying, make the deposit/withdrawal request, store it and allow the user to claim it afterwards. However, it seems simpler to me to create a contract that just holds the receipt tokens, and lets the user retrieve them as soon as the epochId of the main vault is iterated.
    Same thing for a contract that is taking your deposit receipt for auto-request a withdrawal at the next epoch (if we add a "not renew" tick button into our UI).

*** Some things I need to do to have something cleaner
- Remove unusefuls functions for us into ERC6909ib contract.

## Repo specs
The repository itself is an hybrid Foundry/Hardhat project. We made this because we want to be able to do solidity tests as well as js ones.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
