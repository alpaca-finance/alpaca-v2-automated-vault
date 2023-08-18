import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../file-helper/config-file-helper";
import { getDeployer } from "../utils/deployer-helper";
import { Ownable2StepUpgradeable__factory } from "../../typechain/factories/@openzeppelin/contracts-upgradeable/access/index";

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

  const contractToTransfers = [
    config.proxyAdmin,
    config.automatedVault.automatedVaultManager.proxy,
    config.automatedVault.pancakeV3Vault.executor01.proxy,
    config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    config.automatedVault.bank.proxy,
    config.automatedVault.vaults[0].worker,
    config.automatedVault.vaults[1].worker,
    config.automatedVault.vaults[2].worker,
  ];

  const deployer = await getDeployer();
  const opMultiSig = config.opMultiSig;

  for (const contractAddress of contractToTransfers) {
    console.log(`>>> 🔧 Transfer ownership of ${contractAddress} to: ${opMultiSig}`);
    const contract = Ownable2StepUpgradeable__factory.connect(contractAddress, deployer);
    const transferOwnershipTx = await contract.transferOwnership(opMultiSig);
    await transferOwnershipTx.wait();
    console.log(`> 🟢 Done | Tx hash: ${transferOwnershipTx.hash}\n`);
  }

  console.log("\n[Please accept the ownership transfer transaction on multisig wallet]");
  console.log("\n✅ All Done");
};

export default func;
func.tags = ["TransferOwnership"];
