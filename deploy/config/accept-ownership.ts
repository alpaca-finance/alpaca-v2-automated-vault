import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";
import { getDeployer } from "../utils/deployer-helper";
import { ConfigFileHelper } from "../file-helper/config-file-helper";
import { utils } from "ethers";
import { GnosisSafeMultiSigService } from "../services/multisig/gnosis-safe";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const configFileHelper = new ConfigFileHelper();

  const config = configFileHelper.getConfig();
  const deployer = await getDeployer();
  const chainId = await deployer.getChainId();

  /*
    ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
    ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
    ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
    ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
    ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
    ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░
    Check all variables below before execute the deployment script
  */

  const contractToAcceptOwnership = [
    config.automatedVault.automatedVaultManager.proxy,
    config.automatedVault.pancakeV3Vault.executor01.proxy,
    config.automatedVault.pancakeV3Vault.vaultOracle.proxy,
    config.automatedVault.bank.proxy,
    config.automatedVault.vaults[0].worker,
    config.automatedVault.vaults[1].worker,
    config.automatedVault.vaults[2].worker,
  ];

  // funcSig of "acceptOwnership()" should be 0x79ba5097
  const funcSig = ethers.utils.keccak256(utils.toUtf8Bytes("acceptOwnership()")).slice(0, 10);

  const deployerWallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY as string, deployer.provider);

  for (const targetContract of contractToAcceptOwnership) {
    const multiSig = new GnosisSafeMultiSigService(chainId, config.opMultiSig, deployerWallet);
    const txHash = await multiSig.proposeTransaction(targetContract, "0", funcSig);
    console.log(`> 🟢 Transaction Proposed Tx hash: ${txHash}`);
  }
};

export default func;
func.tags = ["AcceptOwnership"];
