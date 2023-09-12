import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer, isFork } from "../../utils/deployer-helper";
import { AutomatedVaultManager__factory } from "../../../typechain/factories/src/AutomatedVaultManager__factory";
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
      vaultTokenAddress: "0xb08eE41e88A2820cd572B4f2DFc459549790F2D7",
      newMaxLeverage: 8,
    },
  ];

  const deployer = await getDeployer();

  const automatedVaultManager = await AutomatedVaultManager__factory.connect(
    config.automatedVault.automatedVaultManager.proxy,
    deployer
  );

  const ops = isFork() ? { gasLimit: 2000000 } : {};
  let nonce = await deployer.getTransactionCount();

  const promises: Array<Promise<ContractTransaction>> = [];
  for (const param of PARAMS) {
    console.log(`> 📝 Vault Token: ${param.vaultTokenAddress}`);
    console.log(`> 📝 Setting Max Leverage ... (${param.newMaxLeverage})`);
    promises.push(
      automatedVaultManager.setMaxLeverage(param.vaultTokenAddress, param.newMaxLeverage, {
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
func.tags = ["SetMaxLeverage"];
