import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();
  const deployer = await getDeployer();

  const AVManagerV3GatewayFactory = await ethers.getContractFactory("AVManagerV3Gateway", deployer);

  const avManagerV3Gateway = await AVManagerV3GatewayFactory.deploy(
    config.automatedVault.automatedVaultManager.proxy,
    config.tokens.wbnb
  );
  console.log(`> 🟢 AVManagerV3Gateway deployed at: ${avManagerV3Gateway.address}`);

  configFileHelper.setAutomatedVaultGateway(avManagerV3Gateway.address);
};

export default func;
func.tags = ["AutomatedVaultGatewayDeploy"];
