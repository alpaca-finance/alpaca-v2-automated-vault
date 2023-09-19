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

  const NAME = "Saving BTCB-BNB 05 PCS1";
  const SYMBOL = "L-BTCBBNB05-PCS1";
  const param: OpenVaultParams = {
    worker: "0x69a86538419eA54E13b85235c19752FD6122BC85",
    vaultOracle: config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    executor: config.automatedVault.pancakeV3Vault.executor01.proxy,
    compressedMinimumDeposit: 5000, // 50 USD
    compressedCapacity: 500_000, // 500,000 USD
    managementFeePerSec: 634195840, // 2% per year
    withdrawalFeeBps: 30, // 0.3%
    toleranceBps: 9975, // inverse 25 bps
    maxLeverage: 6,
  };
  const VAULT_MANAGER = ["0x6EB9bC094CC57e56e91f3bec4BFfe7D9B1802e38", "0xe45216Ac4816A5Ec5378B1D13dE8aA9F262ce9De"];
  const INVEST_TOKEN = config.tokens.wbnb;

  console.log("Open Vault param", param);

  const deployer = await getDeployer();

  const automatedVaultManager = AutomatedVaultManager__factory.connect(
    config.automatedVault.automatedVaultManager.proxy,
    deployer
  );
  const ops = isFork() ? { gasLimit: 2000000 } : {};
  let nonce = await deployer.getTransactionCount();

  const newVaultToken = await automatedVaultManager.callStatic.openVault(NAME, SYMBOL, param, ops);

  const openVaultTx = await automatedVaultManager.openVault(NAME, SYMBOL, param, { ...ops, nonce: nonce++ });
  const openVaultReceipt = await openVaultTx.wait();

  if (openVaultReceipt.status === 1) {
    console.log(`> 🟢 Done Open Vualt: ${openVaultReceipt.transactionHash}`);
    const vaultConfig = config.automatedVault.vaults.find((vault) => compare(vault.worker, param.worker));

    if (vaultConfig) {
      vaultConfig.name = NAME;
      vaultConfig.symbol = SYMBOL;
      vaultConfig.vaultToken = newVaultToken;
      configFileHelper.addOrSetVaultByWorker(vaultConfig);
    }

    console.log("> Setting Allow Token ...");
    const setAllowTokenTx = await automatedVaultManager.setAllowToken(newVaultToken, INVEST_TOKEN, true, {
      ...ops,
      nonce: nonce++,
    });
    console.log(`> 🟢 Done Setting Allow Token: ${setAllowTokenTx.hash}`);

    console.log("> Setting Vault Manager ...");
    const setManagerTxs = await Promise.all(
      VAULT_MANAGER.map((manager) =>
        automatedVaultManager.setVaultManager(newVaultToken, manager, true, { ...ops, nonce: nonce++ })
      )
    );

    console.log(`> 🟢 Done Setting Vault Manager}`);
  }
};

export default func;
func.tags = ["OpenVault"];
