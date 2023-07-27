import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

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

  const POSITION_MANAGER = config.dependencies.pancake.positionManager;
  const BANK = config.automatedVault.bank.proxy;
  const MAX_PRICE_AGE = 60_000;
  const MAX_PRICE_DIFF = 10_500;

  const deployer = await getDeployer();

  const PancakeV3VaultOracleFactory = await ethers.getContractFactory("PancakeV3VaultOracle", deployer);

  const pancakeV3VaultOracle = await upgrades.deployProxy(PancakeV3VaultOracleFactory, [
    POSITION_MANAGER,
    BANK,
    MAX_PRICE_AGE,
    MAX_PRICE_DIFF,
  ]);

  const implAddress = await getImplementationAddress(ethers.provider, pancakeV3VaultOracle.address);

  console.log(`> 🟢 PancakeV3VaultOracle implementation deployed at: ${implAddress}`);
  console.log(`> 🟢 PancakeV3VaultOracle proxy deployed at: ${pancakeV3VaultOracle.address}`);

  configFileHelper.setPancakeV3VaultOracle(pancakeV3VaultOracle.address, implAddress);
};

export default func;
func.tags = ["PancakeV3VaultOracleDeploy"];
