import { AutomatedVaultManager__factory } from "./../../../typechain/factories/src/AutomatedVaultManager__factory";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer, isFork } from "../../utils/deployer-helper";
import { compare } from "../../utils/address";

interface OpenVaultParams {
  worker: string;
  vaultOracle: string;
  executor: string;
  compressedMinimumDeposit: number;
  compressedCapacity: number;
  managementFeePerSec: number;
  withdrawalFeeBps: number;
  toleranceBps: number;
  maxLeverage: number;
}
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();
  /*
  ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
  ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
  ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
  ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
  ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░
  Check all variables below before execute the deployment script
  */

  const NAME = "Market Neutral USDC-USDT 01 PCS1";
const SYMBOL = "N-USDCUSDT01-PCS1";
const param: OpenVaultParams = {
    worker: "0x884Aa0332800dB0a15527682b8FE26C2444E4200",
    vaultOracle: config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    executor: config.automatedVault.pancakeV3Vault.executor01.proxy,
    compressedMinimumDeposit: 5000, // 50 USD
    compressedCapacity: 250_000, // 250,000 USD
    managementFeePerSec: 634195840, // 2% per year
    withdrawalFeeBps: 30, // 0.3%
    toleranceBps: 9975, // inverse 25 bps
    maxLeverage: 8,
  };
const VAULT_MANAGER = "0x6EB9bC094CC57e56e91f3bec4BFfe7D9B1802e38";
const INVEST_TOKEN = config.tokens.usdt;

  console.log("Open Vault param", param);

  const deployer = await getDeployer();

  const automatedVaultManager = AutomatedVaultManager__factory.connect(
    config.automatedVault.automatedVaultManager.proxy,
    deployer
  );
  const ops = isFork() ? { gasLimit: 2000000 } : {};

  const newVaultToken = await automatedVaultManager.callStatic.openVault(NAME, SYMBOL, param, ops);

  const openVaultTx = await automatedVaultManager.openVault(NAME, SYMBOL, param, ops);
  const openVaultReceipt = await openVaultTx.wait();

  if (openVaultReceipt.status === 1) {
    console.log(`> 🟢 Done Open Vualt: ${openVaultReceipt.transactionHash}`);
    const vaultConfig = config.automatedVault.pancakeV3Vault.vaults.find((vault) =>
      compare(vault.worker, param.worker)
    );

    if (vaultConfig) {
      vaultConfig.name = NAME;
      vaultConfig.symbol = SYMBOL;
      vaultConfig.vaultToken = newVaultToken;
      configFileHelper.addOrSetPCSV3VaultByWorker(vaultConfig);
    }

    console.log("> Setting Allow Token ...");
    const setAllowTokenTx = await automatedVaultManager.setAllowToken(newVaultToken, INVEST_TOKEN, true);
    console.log(`> 🟢 Done Setting Allow Token: ${setAllowTokenTx.hash}`);

    console.log("> Setting Vault Manager ...");
    const setVaultManagetTx = await automatedVaultManager.setVaultManager(newVaultToken, VAULT_MANAGER, true);
    console.log(`> 🟢 Done Setting Vault Manager: ${setVaultManagetTx.hash}`);
  }
};

export default func;
func.tags = ["OpenVault"];
