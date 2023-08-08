import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../file-helper/config-file-helper";
import { getDeployer } from "../utils/deployer-helper";
import { getProxyAdminFactory } from "@openzeppelin/hardhat-upgrades/dist/utils";
import { AutomatedVaultManager__factory, Bank__factory } from "../../typechain/factories/src";
import { PCSV3Executor01__factory } from "../../typechain/factories/src/executors";
import { PancakeV3Worker__factory } from "../../typechain/factories/src/workers";
import { PancakeV3VaultOracle__factory } from "../../typechain/factories/src/oracles";

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

  const deployer = await getDeployer();

  const opMultiSig = config.opMultiSig;

  const proxyAdminFactory = getProxyAdminFactory(hre, deployer);
  const proxyAdmin = (await proxyAdminFactory).attach(config.proxyAdmin);
  const avManager = AutomatedVaultManager__factory.connect(config.automatedVault.automatedVaultManager.proxy, deployer);
  const executor01 = PCSV3Executor01__factory.connect(config.automatedVault.pancakeV3Vault.executor01.proxy, deployer);
  const vaultOracle = PancakeV3VaultOracle__factory.connect(
    config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    deployer
  );
  const bank = Bank__factory.connect(config.automatedVault.bank.proxy, deployer);
  // Saving USDT-BNB 05 PCS1 Vault
  const worker = PancakeV3Worker__factory.connect(config.automatedVault.pancakeV3Vault.vaults[0].worker, deployer);

  console.log(">>> 🔧 Transfer ownership of Automated Vault");

  console.log(`> 🟢 Transferring ProxyAdmin ownership to: ${opMultiSig}`);
  const proxyAdminTransferOwnershipTx = await proxyAdmin.transferOwnership(opMultiSig);
  await proxyAdminTransferOwnershipTx.wait();
  console.log(`> 🟢 Done | Tx hash: ${proxyAdminTransferOwnershipTx.hash}\n`);

  // 2 Steps Ownership Transfer
  console.log(`> 🟢 Transferring AutomatedVaultManager ownership to: ${opMultiSig}`);
  const avManagerTransferOwnershipTx = await avManager.transferOwnership(opMultiSig);
  await avManagerTransferOwnershipTx.wait();
  console.log(`> 🟢 Done | Tx hash: ${avManagerTransferOwnershipTx.hash}\n`);

  // 2 Steps Ownership Transfer
  console.log(`> 🟢 Transferring PCSV3Executor01 ownership to: ${opMultiSig}`);
  const executor01TransferOwnershipTx = await executor01.transferOwnership(opMultiSig);
  await executor01TransferOwnershipTx.wait();
  console.log(`> 🟢 Done | Tx hash: ${executor01TransferOwnershipTx.hash}\n`);

  // 2 Steps Ownership Transfer
  console.log(`> 🟢 Transferring PancakeV3VaultOracle ownership to: ${opMultiSig}`);
  const vaultOracleTransferOwnershipTx = await vaultOracle.transferOwnership(opMultiSig);
  await vaultOracleTransferOwnershipTx.wait();
  console.log(`> 🟢 Done | Tx hash: ${vaultOracleTransferOwnershipTx.hash}\n`);

  // 2 Steps Ownership Transfer
  console.log(`> 🟢 Transferring Bank ownership to: ${opMultiSig}`);
  const bankTransferOwnershipTx = await bank.transferOwnership(opMultiSig);
  await bankTransferOwnershipTx.wait();
  console.log(`> 🟢 Done | Tx hash: ${bankTransferOwnershipTx.hash}\n`);

  // 2 Steps Ownership Transfer
  console.log(`> 🟢 Transferring PancakeV3Worker ownership to: ${opMultiSig}`);
  const workerTransferOwnershipTx = await worker.transferOwnership(opMultiSig);
  await workerTransferOwnershipTx.wait();
  console.log(`> 🟢 Done | Tx hash: ${workerTransferOwnershipTx.hash}\n`);

  console.log("\n[Please accept the ownership transfer transaction on multisig wallet]");
  console.log("\n✅ All Done");
};

export default func;
func.tags = ["TransferOwnership"];
