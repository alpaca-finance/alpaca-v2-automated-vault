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

  const AUTOMATED_VAULT_MANAGER = config.automatedVault.automatedVaultManager.proxy;
  const BANK = config.automatedVault.bank.proxy;
  const VAULT_ORACLE = config.automatedVault.pancakeV3Vault.vaultOracle.proxy;
  const REPURCHASE_SLIPPAGE_BPS = 100;

  const deployer = await getDeployer();

  const PCSV3Executor01Factory = await ethers.getContractFactory("PCSV3Executor01", deployer);

  console.log(`> Deploying PCSV3Executor01 ...`);

  const pcsV3Executor01 = await upgrades.deployProxy(PCSV3Executor01Factory, [
    AUTOMATED_VAULT_MANAGER,
    BANK,
    VAULT_ORACLE,
    REPURCHASE_SLIPPAGE_BPS,
  ]);

  const implAddress = await getImplementationAddress(ethers.provider, pcsV3Executor01.address);

  console.log(`> 🟢 PCSV3Executor01 implementation deployed at: ${implAddress}`);
  console.log(`> 🟢 PCSV3Executor01 proxy deployed at: ${pcsV3Executor01.address}`);

  configFileHelper.setPancakeV3Executor(pcsV3Executor01.address, implAddress);
};

export default func;
func.tags = ["PancakeV3Executor01Deploy"];
