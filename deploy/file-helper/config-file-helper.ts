import { Config, Vault } from "../interfaces";
import MainnetConfig from "../../.mainnet.json";
import * as fs from "fs";

export class ConfigFileHelper {
  private filePath: string;
  private config: Config;
  constructor() {
    this.filePath = ".mainnet.json";
    this.config = MainnetConfig;
  }

  public getConfig() {
    return this.config;
  }

  public setProxyAdmin(address: string) {
    this.config.proxyAdmin = address;
    this._writeConfigFile(this.config);
  }

  public setAutomatedVaultERC20Implementation(address: string) {
    this.config.automatedVault.automatedVaultERC20Implementation = address;
    this._writeConfigFile(this.config);
  }

  public setAutomatedVaultManager(proxy: string, implementation: string) {
    this.config.automatedVault.automatedVaultManager.proxy = proxy;
    this.config.automatedVault.automatedVaultManager.implementation = implementation;
    this._writeConfigFile(this.config);
  }

  public setAutomatedVaultGateway(address: string) {
    this.config.automatedVault.avManagerV3Gateway = address;
    this._writeConfigFile(this.config);
  }

  public setPancakeV3VaultOracle(proxy: string, implementation: string) {
    this.config.automatedVault.pancakeV3Vault.vaultOracle.proxy = proxy;
    this.config.automatedVault.pancakeV3Vault.vaultOracle.implementation = implementation;
    this._writeConfigFile(this.config);
  }

  public setPancakeV3Executor(proxy: string, implementation: string) {
    this.config.automatedVault.pancakeV3Vault.executor01.proxy = proxy;
    this.config.automatedVault.pancakeV3Vault.executor01.implementation = implementation;
    this._writeConfigFile(this.config);
  }

  public setBank(proxy: string, implementation: string) {
    this.config.automatedVault.bank.proxy = proxy;
    this.config.automatedVault.bank.implementation = implementation;
    this._writeConfigFile(this.config);
  }

  public addPCSV3Worker(address: string) {
    this.config.automatedVault.pancakeV3Vault.vaults.push({ name: "", symbol: "", vaultToken: "", worker: address });
    this._writeConfigFile(this.config);
  }

  public addOrSetPCSV3VaultByWorker(vault: Vault) {
    const index = this.config.automatedVault.pancakeV3Vault.vaults.findIndex((vault) => vault.worker);
    if (index === -1) {
      this.config.automatedVault.pancakeV3Vault.vaults.push(vault);
    } else {
      this.config.automatedVault.pancakeV3Vault.vaults[index] = vault;
    }
    this._writeConfigFile(this.config);
  }

  private _writeConfigFile(config: Config) {
    console.log(`>> Writing ${this.filePath}`);
    fs.writeFileSync(this.filePath, JSON.stringify(config, null, 2));
    console.log("✅ Done");
  }
}
