## Asynchronous Amphor vaults

**This repository implements the ERC-7540, it should so be considered as a draft since the standard is still in review state.**
**In addition, this code is itself a first draft and contains multiple bugs and potential vulnerabilities.**

### Problem solved:  
- The Amphor strategy currently works with epochs, so deposits and withdrawals are only active between these. Because of this strategy system, we are forced to not farm during a certain amount of time in order to let users deposit between periods. Also, this is highly decreasing the user experience because they cannot deposit or withdraw when they want but instead need to be here at the right moment.
- Thank to the deposit and withdraw request system we will be able to bypass these problems.

## Repo specs
The repository itself is an hybrid Foundry/Hardhat project. We made this because we want to be able to do solidity tests as well as js ones and we were not fully happy with ffi.

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
