import { Config, Vault } from "../interfaces";
import MainnetConfig from "../../.mainnet.json";
import * as fs from "fs";
import { compare } from "../utils/address";

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

  public setPancakeV3VaultReader(address: string) {
    this.config.readers.pancakeV3VaultReader = address;
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

  public addVaultWorker(address: string, token0Address: string, token1Address: string) {
    this.config.automatedVault.vaults.push({
      name: "",
      symbol: "",
      vaultToken: "",
      worker: address,
      token0: token0Address,
      token1: token1Address,
    });
    this._writeConfigFile(this.config);
  }

  public addOrSetVaultByWorker(newVault: Vault) {
    const index = this.config.automatedVault.vaults.findIndex((vault) => compare(vault.worker, newVault.worker));

    if (index === -1) {
      this.config.automatedVault.vaults.push(newVault);
    } else {
      this.config.automatedVault.vaults[index] = newVault;
    }
    this._writeConfigFile(this.config);
  }

  private _writeConfigFile(config: Config) {
    console.log(`>> Writing ${this.filePath}`);
    fs.writeFileSync(this.filePath, JSON.stringify(config, null, 2));
    console.log("✅ Done");
  }
}
