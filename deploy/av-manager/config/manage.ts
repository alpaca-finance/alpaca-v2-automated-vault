import { PCSV3Executor01__factory } from "./../../../typechain/factories/src/executors/PCSV3Executor01__factory";
import { AutomatedVaultManager__factory } from "./../../../typechain/factories/src/AutomatedVaultManager__factory";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer, isFork } from "../../utils/deployer-helper";
import { BigNumber } from "ethers";

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
  const pcsV3Executor01 = PCSV3Executor01__factory.connect(
    config.automatedVault.pancakeV3Vault.executor01.proxy,
    deployer
  );

  const vaultTokenAddress = "0x8Ee3A53720ED344e7CBfAe63292c18E4183CCE8a";
  const commands = [pcsV3Executor01.interface.encodeFunctionData("deleverage", [BigNumber.from(10000)])];

  const automatedVaultManager = AutomatedVaultManager__factory.connect(
    config.automatedVault.automatedVaultManager.proxy,
    deployer
  );
  const ops = isFork() ? { gasLimit: 2000000 } : {};
  let nonce = await deployer.getTransactionCount();

  const tx = await automatedVaultManager.manage(vaultTokenAddress, commands, {
    ...ops,
    nonce: nonce++,
  });

  const manageReceipt = await tx.wait();

  console.log(`> ✅ Done at! ${manageReceipt.transactionHash}`);
};

export default func;
func.tags = ["Manage"];
