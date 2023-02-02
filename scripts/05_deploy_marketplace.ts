import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  const singleNFT = await deployments.get("SingleNFT");
  const multiNFT = await deployments.get("MultiNFT");
  const ownershipCertificate = await deployments.get("OwnershipCertificate");
  const license = await deployments.get("License");

  let WETH = await deployments.getOrNull("WETH");
  if (!WETH) {
    WETH = await deploy("WETH", {
      from: deployer,
      contract: "MockWETH",
      log: true,
    });
  }

  await deploy("Marketplace", {
    from: deployer,
    contract: "Marketplace",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          WETH.address,
          singleNFT.address,
          multiNFT.address,
          ownershipCertificate.address,
          license.address,
          deployer,
        ],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["Marketplace", "Marketplace_deploy"];
func.dependencies = [
  "SingleNFT",
  "MultiNFT",
  "OwnershipCertificate",
  "License",
];
