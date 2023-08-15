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
    { token: config.tokens.btcb, priceFeed: "0x264990fbd0a4796a3e3d8e37c4d5f87a3aca5ebf" },
    { token: config.tokens.eth, priceFeed: "0x9ef1b8c0e4f7dc8bf5719ea496883dc6401d5b2e" },
    { token: config.tokens.cake, priceFeed: "0xb6064ed41d4f67e353768aa239ca86f4f73665a1" },
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
