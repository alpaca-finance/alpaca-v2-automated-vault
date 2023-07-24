import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = await getDeployer();

  const AutomatedVaultERC20Factory = await ethers.getContractFactory("AutomatedVaultERC20", deployer);

  const AutomatedVaultERC20 = await AutomatedVaultERC20Factory.deploy();
  console.log(`> 🟢 AutomatedVaultERC20Implementation deployed at: ${AutomatedVaultERC20.address}`);

  const configFileHelper = new ConfigFileHelper();
  configFileHelper.setAutomatedVaultERC20Implementation(AutomatedVaultERC20.address);
};

export default func;
func.tags = ["AutomatedVaultImplementationDeploy"];
