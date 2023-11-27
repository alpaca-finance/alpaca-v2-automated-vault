import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";

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

  const automatedVaultManager = config.automatedVault.automatedVaultManager.proxy;

  const deployer = await getDeployer();

  const automatedVaultManagerFactory = await ethers.getContractFactory("AutomatedVaultManager", deployer);

  const preparedAutomatedVaultManager = await upgrades.prepareUpgrade(
    automatedVaultManager,
    automatedVaultManagerFactory
  );
  console.log(`> New Implementation address: ${preparedAutomatedVaultManager}`);

  await upgrades.upgradeProxy(automatedVaultManager, automatedVaultManagerFactory);
  console.log("✅ Done");

  configFileHelper.setAutomatedVaultManager(automatedVaultManager, preparedAutomatedVaultManager);
};

export default func;
func.tags = ["AutomatedVaultManagerUpgrade"];
