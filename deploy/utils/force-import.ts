import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { makeForceImport } from "@openzeppelin/hardhat-upgrades/dist/force-import";
import { getDeployer } from "./deployer-helper";
import { ethers, upgrades } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = await getDeployer();

  const contractName = "PancakeV3Worker";
  const contractAddress = "0x2f44C3a223ccB3da6FCD9Abe4c3aeda79e4ebd34";

  const ContractFactory = await ethers.getContractFactory(contractName, deployer);
  const forceimport = makeForceImport(hre);
  await forceimport(contractAddress, ContractFactory);

  console.log("✅ Done");
};

export default func;
func.tags = ["ForceImport"];
