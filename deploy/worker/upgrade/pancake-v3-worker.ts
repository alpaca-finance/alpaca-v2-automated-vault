import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();
  const deployer = await getDeployer();

  /*
  ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
  ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
  ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
  ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
  ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░
  Check all variables below before execute the deployment script
  */

  const WORKERS = [
    "0x463039266657602f60fc70De00553772f3cf4392",
    "0x884Aa0332800dB0a15527682b8FE26C2444E4200",
    "0x831849c40B651F6E8C11108CF648f34a9C3add7A",
    "0xC5978748e0812744F9E7ef9aEB30548C7cE7ED6f",
    "0x69a86538419eA54E13b85235c19752FD6122BC85",
  ];

  const PancakeV3WorkerFactory = await ethers.getContractFactory("PancakeV3Worker", deployer);

  for (const worker of WORKERS) {
    const preparedPancakeV3Worker = await upgrades.prepareUpgrade(worker, PancakeV3WorkerFactory);

    console.log(`>> New implementation deployed at: ${preparedPancakeV3Worker}`);
    await upgrades.upgradeProxy(worker, PancakeV3WorkerFactory);

    console.log(`>> Done upgrade : ${worker}`);
  }
};

export default func;
func.tags = ["PancakeV3WorkerUpgrade"];
