# This file contains the tests rules.
You can add new rules below.

- Global vault values and specific vault global values should be in separate
contracts.
- Global `ERC20` assets should be as much as possible casted as `ERC20` (instead
of `address` or `IERC20`) in order to simplify the business logic and contain
some `IERC20` code extension like `IERC20Metadata`.
- Tests should contains a specific tests contract for each production contract,
specific(s) contract(s) for properties, and specific(s) contract(s) for basics
scenarios.
