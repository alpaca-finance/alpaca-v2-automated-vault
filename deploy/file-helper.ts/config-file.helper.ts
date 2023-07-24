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

  private _writeConfigFile(config: Config) {
    console.log(`>> Writing ${this.filePath}`);
    fs.writeFileSync(this.filePath, JSON.stringify(config, null, 2));
    console.log("✅ Done");
  }
}
