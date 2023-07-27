import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();
  const deployer = await getDeployer();

  const PancakeV3VaultReaderFactory = await ethers.getContractFactory("PancakeV3VaultReader", deployer);

  const pancakeV3VaultReader = await PancakeV3VaultReaderFactory.deploy(
    config.automatedVault.automatedVaultManager.proxy,
    config.automatedVault.bank.proxy,
    config.automatedVault.pancakeV3Vault.vaultOracle.proxy
  );
  console.log(`> 🟢 PancakeV3VaultReader deployed at: ${pancakeV3VaultReader.address}`);

  configFileHelper.setPancakeV3VaultReader(pancakeV3VaultReader.address);
};

export default func;
func.tags = ["PancakeV3VaultReaderDeploy"];
