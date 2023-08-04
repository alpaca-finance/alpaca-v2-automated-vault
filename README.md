# Alpaca Finance 2.0 Automated Vault

## Background

Instead of holding crypto assets and constructing a portfolio by themselves, investors can invest into the vault that will perform different strategies. This can also be compared with how traditional mutual funds work where investors buy shares of the funds expecting that the fund managers will be able to deploy their money profitably. Nevertheless, in traditional finance most of the investment happens behind the scenes, the automated vault’s goal is to provide a secure and transparent investment pool.

## Terminology

- Vault - The abstraction of mutual funds where investors can invest into.
- Position Value - The value of deployed funds to destination protocol denominated by US Dollar. In the first version, the position value is calculated by pricing the PancakeSwapV3’s LP position.
- Debt Value - The value of borrowed funds denominated by US Dollar.
Undeployed Funds - The value of tokens pending to be deployed into the position denominated by US Dollar. 
- Equity - The value that belongs to the vault. This can be calculated by (Position Value + Undeployed Funds) - Debt
- AUM - The value of assets under management. This can be calculated by Position Value + Undeployed Funds + Debt Value.
- Debt Ratio - The ratio of debt over overall Aum. This can be calculated by Debt Value / AUM
- Leverage - The multiplier of Aum over equity. Can be calculated by Aum / Equity.
- Exposure - The amount of token that is either an excess in holding or outstanding to be repaid


## Building Blocks

- AutomatedVaultManager - An entry point contract to perform all actions e.g deposit, withdraw, manage. The contract is responsible for minting and burning ERC-20 AV tokens.

- AutomatedVaultToken (AV Token)- An ERC-20 contract that represents the ownership of the vault.

- Executor - A brain of the vault which will be called from AutomatedVaultManager to perform a combination of tasks to manipulate the underlying position, undeployed funds, and debt.

- Worker - A contract that holds the position of the vault. This contract contains the logic to interact with DEX e.g entering position, exiting position, claim reward / fee.

- Bank - A contract that will provide a loan to a vault. This acts as an intermediary contract that will perform “non-collateralized” borrowings from AF2.0 Money Market. All vaults that borrow the tokens from the bank will all share the same interest rate

- VaultOracle - A contract that evaluates the total equity of the vault. The equity will be used to determine how much AV Token should be minted.
