import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";
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
  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();
  const deployer = await getDeployer();
  const BankFactory = await ethers.getContractFactory("Bank", deployer);

  console.log(`> Deploying Bank Contract`);
  const bank = await upgrades.deployProxy(BankFactory, [
    config.dependencies.moneyMarket,
    config.automatedVault.automatedVaultManager.proxy,
  ]);

  const implAddress = await getImplementationAddress(ethers.provider, bank.address);

  console.log(`> 🟢 bank implementation deployed at: ${implAddress}`);
  console.log(`> 🟢 bank proxy deployed at: ${bank.address}`);

  configFileHelper.setBank(bank.address, implAddress);
};

export default func;
func.tags = ["BankDeploy"];
