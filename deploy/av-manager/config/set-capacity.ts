import { AutomatedVaultManager__factory } from "./../../../typechain/factories/src/AutomatedVaultManager__factory";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer, isFork } from "../../utils/deployer-helper";
import { ContractTransaction } from "ethers";

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
  const PARAMS = [
    {
      vaultTokenAddress: "0xd99386173CF5A93d83d1958e985f361696A75A3e",
      newCompressedCapacity: 0,
    },
  ];

  const deployer = await getDeployer();

  const automatedVaultManager = AutomatedVaultManager__factory.connect(
    config.automatedVault.automatedVaultManager.proxy,
    deployer
  );
  const ops = isFork() ? { gasLimit: 2000000 } : {};
  let nonce = await deployer.getTransactionCount();

  const promises: Array<Promise<ContractTransaction>> = [];
  for (const pam of PARAMS) {
    console.log(`> 📝 Vault Token: ${pam.vaultTokenAddress}`);
    console.log(`> 📝 Setting Capacity ... (${pam.newCompressedCapacity})`);
    promises.push(
      automatedVaultManager.setCapacity(pam.vaultTokenAddress, pam.newCompressedCapacity, {
        ...ops,
        nonce: nonce++,
      })
    );
  }
  console.log(`> Submitting txs...`);
  const txs = await Promise.all(promises);
  console.log(`> Waiting for confirmations...`);
  await txs[txs.length - 1].wait(3);
  console.log(`> ✅ Done!`);
};

export default func;
func.tags = ["SetCapacity"];
