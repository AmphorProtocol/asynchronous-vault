// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestOpen {
    function test_GivenVaultIsOpenWhenOpen() external {
        // it should revert with VaultIsOpen
    }

    function test_GivenMsgSenderIsNotOwnerWhenOpen() external {
        // it should revert with OwnableUnauthorizedAccount(msg.sender)
    }

    function test_GivenAssetReturnedIs0AndTotalsAssetsIsNot0AndMaxDrawdownIsNot0WhenOpen() external {
        // it should revert with MaxDrawdownReached
    }

    function test_GivenAssetReturnedIs1AndTotalsAssetsIsOverAssetsReturnedAndMaxDrawdownIsNot0WhenOpen() external {
        // it should revert with MaxDrawdownReached
    }

    function test_WhenOpenSucceed() external {
        // it should set isOpen to true
        // it should emit EpochEnd(block.timestamp, _totalAssets, assetReturned, fees, totalSupply())
        // it should _mint previewDeposit(pendingDeposit)
        // it should emit Deposit(address(this), address(this), pendingDeposit, previewDeposit(pendingDeposit))
        // it should _deposit the pendingDeposit value to the vault
        // it should emit Deposit(address(this), msg.sender, pendingDeposit, previewDeposit(pendingDeposit))
        // it should increase the total claimableShares of previewDeposit(pendingDeposit)
        // it should redeem pendingRedeem value from the vault
        // it should emit Withdraw(address(this), msg.sender, pendingRedeem, previewRedeem(pendingRedeem))
        // it should verify totalAssets == totalsAssetsBefore - assetsToRedeem + pendingDeposit
        // it should verify totalSupply == totalSupplyBefore + previewDeposit(pendingDeposit) - pendingRedeem
    }

    function test_GivenPeriodIsInProfitWhenOpen() external {
        // it should transfer assetsReturned - ((totalAssets - assetReturned) * fees / 10 000) from msg.sender to the vault
        // it should pass when open succeed
    }

    function test_GivenPeriodIsInLossWhenOpen() external {
        // it should transfer assetsReturned from msg.sender to the vault
        // it should pass when open succeed
    }
}
