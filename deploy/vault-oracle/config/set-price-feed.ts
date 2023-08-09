import { PancakeV3VaultOracle__factory } from "./../../../typechain/factories/src/oracles/PancakeV3VaultOracle__factory";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
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

  const PRICE_FEED_LIST = [
    { token: config.tokens.usdc, priceFeed: "0x51597f405303c4377e36123cbc172b13269ea163" }
  ];

  const deployer = await getDeployer();

  const vaultOracle = PancakeV3VaultOracle__factory.connect(
    config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    deployer
  );
  let nonce = await deployer.getTransactionCount();
  for (const priceFeed of PRICE_FEED_LIST) {
    const setPriceFeedTx = await vaultOracle.setPriceFeedOf(priceFeed.token, priceFeed.priceFeed, { nonce: nonce++ });
    console.log(`> 🟢 Done Setting price feed hash: ${setPriceFeedTx.hash}`);
  }
};

export default func;
func.tags = ["SetPriceFeedOf"];
