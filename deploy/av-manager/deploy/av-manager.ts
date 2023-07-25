import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
  ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
  ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
  ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
  ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
  ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░
  Check all variables below before execute the deployment script
  */

  const MANAGEMENT_FEE_TREASURY = "";
  const WITHDRAWAL_FEE_TREASURY = "";

  const deployer = await getDeployer();

  const AutomatedVaultManagerFactory = await ethers.getContractFactory("AutomatedVaultManager", deployer);

  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();

  const automatedVaultManager = await upgrades.deployProxy(AutomatedVaultManagerFactory, [
    config.automatedVault.automatedVaultERC20Implementation,
    MANAGEMENT_FEE_TREASURY,
    WITHDRAWAL_FEE_TREASURY,
  ]);

  const implAddress = await getImplementationAddress(ethers.provider, automatedVaultManager.address);

  console.log(`> 🟢 AutomatedVaultManager implementation deployed at: ${implAddress}`);
  console.log(`> 🟢 AutomatedVaultManager proxy deployed at: ${automatedVaultManager.address}`);

  configFileHelper.setAutomatedVaultManager(automatedVaultManager.address, implAddress);
};

export default func;
func.tags = ["AutomatedVaultManagerDeploy"];
