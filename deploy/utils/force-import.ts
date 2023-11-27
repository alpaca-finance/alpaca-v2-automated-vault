import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { makeForceImport } from "@openzeppelin/hardhat-upgrades/dist/force-import";
import { getDeployer } from "./deployer-helper";
import { ethers, upgrades } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = await getDeployer();

  const contractName = "AutomatedVaultManager";
  const contractAddress = "0x04Cbe4116a23a5AF2f67DBBd04F3e18dF20457E7";

  const ContractFactory = await ethers.getContractFactory(contractName, deployer);
  const forceimport = makeForceImport(hre);
  await forceimport(contractAddress, ContractFactory);

  console.log("✅ Done");
};

export default func;
func.tags = ["ForceImport"];
