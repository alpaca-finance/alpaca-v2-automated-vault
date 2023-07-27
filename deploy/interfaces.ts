interface UpgradableContract {
  implementation: string;
  proxy: string;
}

export interface Tokens {
  wbnb: string;
  usdt: string;
  cake: string;
}

export interface Dependency {
  moneyMarket: string;
  pancake: Pancake;
  zapV3: string;
}

export interface Pancake {
  masterChef: string;
  positionManager: string;
  swapRouter: string;
  factoryV3: string;
  pools: Record<string, string>;
}

export interface PancakeV3Vault {
  vaultOracle: UpgradableContract;
  executor01: UpgradableContract;
  pancakeV3VaultReader: string;
  vaults: Vault[];
}

export interface Vault {
  name: string;
  symbol: string;
  vaultToken: string;
  worker: string;
}

export interface AutomatedVault {
  automatedVaultERC20Implementation: string;
  avManagerV3Gateway: string;
  automatedVaultManager: UpgradableContract;
  bank: UpgradableContract;
  pancakeV3Vault: PancakeV3Vault;
}

export interface Config {
  proxyAdmin: string;
  performanceFeeBucket: string;
  tokens: Tokens;
  automatedVault: AutomatedVault;
  dependencies: Dependency;
}
