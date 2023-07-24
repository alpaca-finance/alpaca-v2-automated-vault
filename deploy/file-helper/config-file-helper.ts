import { Config } from "../interfaces";
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

  private _writeConfigFile(config: Config) {
    console.log(`>> Writing ${this.filePath}`);
    fs.writeFileSync(this.filePath, JSON.stringify(config, null, 2));
    console.log("✅ Done");
  }
}
