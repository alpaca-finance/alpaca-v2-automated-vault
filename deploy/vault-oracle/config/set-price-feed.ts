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
    { token: config.tokens.usdt, priceFeed: "0xb97ad0e74fa7d920791e90258a6e2085088b4320" },
    { token: config.tokens.wbnb, priceFeed: "0x0567f2323251f0aab15c8dfb1967e4e8a7d42aee" },
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
