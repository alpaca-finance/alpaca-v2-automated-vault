interface UpgradableContract {
  implementation: string;
  proxy: string;
}

export interface Tokens {
  btcb: string;
  cake: string;
  eth: string;
  usdc: string;
  usdt: string;
  wbnb: string;
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

export interface Reader {
  pancakeV3VaultReader: string;
}

export interface Config {
  proxyAdmin: string;
  performanceFeeBucket: string;
  opMultiSig: string;
  tokens: Tokens;
  readers: Reader;
  automatedVault: AutomatedVault;
  dependencies: Dependency;
}
