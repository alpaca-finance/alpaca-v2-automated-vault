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

  const pcsV3Executor01 = config.automatedVault.pancakeV3Vault.executor01.proxy;
  
  const deployer = await getDeployer();

  const PCSV3Executor01Factory = await ethers.getContractFactory("PCSV3Executor01", deployer);

  const preparedNewPCSV3Executor01 = await upgrades.prepareUpgrade(pcsV3Executor01, PCSV3Executor01Factory);
  console.log(`> New Implementation address: ${preparedNewPCSV3Executor01}`);

  await upgrades.upgradeProxy(pcsV3Executor01, PCSV3Executor01Factory);
  console.log("✅ Done");

  configFileHelper.setPancakeV3Executor(pcsV3Executor01, preparedNewPCSV3Executor01);
};

export default func;
func.tags = ["PancakeV3Executor01Upgrade"];
