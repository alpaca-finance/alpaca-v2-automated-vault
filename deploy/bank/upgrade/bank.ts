import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ProxyAdmin__factory } from "../../../typechain/factories/src/upgradable/ProxyAdmin.sol/ProxyAdmin__factory";
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

  const bank = config.automatedVault.bank.proxy;

  const deployer = await getDeployer();

  const bankFactory = await ethers.getContractFactory("Bank", deployer);

  const preparedBank = await upgrades.prepareUpgrade(bank, bankFactory);
  console.log(`> New Implementation address: ${preparedBank}`);

  const proxyAdmin = ProxyAdmin__factory.connect(config.proxyAdmin, deployer);
  const upgradeTx = await proxyAdmin.upgrade(bank, preparedBank);

  const upgradeReceipt = await upgradeTx.wait();

  console.log(`> 🟢 Done Bank implementation upgraded tx ${upgradeReceipt.transactionHash}`);

  configFileHelper.setBank(bank, preparedBank);
};

export default func;
func.tags = ["BankUpgrade"];
