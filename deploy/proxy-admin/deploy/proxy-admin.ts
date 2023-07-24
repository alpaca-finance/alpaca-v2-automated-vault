import { getProxyAdminFactory } from "@openzeppelin/hardhat-upgrades/dist/utils";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = await getDeployer();
  const proxyAdminFactory = await getProxyAdminFactory(hre, deployer);

  const proxyAdmin = await proxyAdminFactory.deploy();
  console.log(`> 🟢 ProxyAdmin deployed at: ${proxyAdmin.address}`);

  const configFileHelper = new ConfigFileHelper();
  configFileHelper.setProxyAdmin(proxyAdmin.address);
};

export default func;
func.tags = ["ProxyAdminDeploy"];
