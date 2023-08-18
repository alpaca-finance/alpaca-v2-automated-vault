import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployer } from "../../utils/deployer-helper";
import { ProxyAdmin__factory } from "../../../typechain/factories/src/upgradable/ProxyAdmin.sol/ProxyAdmin__factory";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = await getDeployer();
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

  const newProxyAdmin = "0xdAb7a2cca461F88eedBadF448C3957Ff20Cea1a7";
  const contractToChangeAdmin = [
    config.automatedVault.bank.proxy,
    config.automatedVault.automatedVaultManager.proxy,
    config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    config.automatedVault.pancakeV3Vault.executor01.proxy,
    config.automatedVault.vaults[0].worker,
  ];

  const proxyAdmin = ProxyAdmin__factory.connect(config.proxyAdmin, deployer);
  let nonce = await deployer.getTransactionCount();
  for (const contractAddress of contractToChangeAdmin) {
    const transferAdminTx = await proxyAdmin.changeProxyAdmin(contractAddress, newProxyAdmin, { nonce: nonce++ });
    const transferReceipt = await transferAdminTx.wait();

    console.log(`🟢 Done transfer tx ${transferReceipt.transactionHash}`);
  }

  configFileHelper.setProxyAdmin(newProxyAdmin);
};

export default func;
func.tags = ["TransferProxyAdmin"];
