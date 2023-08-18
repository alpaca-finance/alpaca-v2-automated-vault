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
      vaultTokenAddress: "0xb08eE41e88A2820cd572B4f2DFc459549790F2D7se",
      manager: "0xe45216ac4816a5ec5378b1d13de8aa9f262ce9de",
      isOk: true,
    },
    {
      vaultTokenAddress: "0x8Ee3A53720ED344e7CBfAe63292c18E4183CCE8a",
      manager: "0xe45216ac4816a5ec5378b1d13de8aa9f262ce9de",
      isOk: true,
    },
    {
      vaultTokenAddress: "0xdEBe96323D54d4D58F4bB526e58627Fb0651Bb00",
      manager: "0xe45216ac4816a5ec5378b1d13de8aa9f262ce9de",
      isOk: true,
    },
    {
      vaultTokenAddress: "0x0C8ECaE87711d766fAA18047B3450479b4e822d4",
      manager: "0xe45216ac4816a5ec5378b1d13de8aa9f262ce9de",
      isOk: true,
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
    console.log(`> 📝 Setting Manager: (${pam.manager}), isOk: ${pam.isOk}`);
    promises.push(
      automatedVaultManager.setVaultManager(pam.vaultTokenAddress, pam.manager, pam.isOk, {
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
func.tags = ["SetVaultManager"];
