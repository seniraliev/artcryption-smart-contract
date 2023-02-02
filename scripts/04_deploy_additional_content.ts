import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  const marketplace = await deployments.get("ArtcryptionMarketplace");

  await deploy("AdditionalContent", {
    from: deployer,
    contract: "AdditionalContent",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [marketplace.address],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["AdditionalContent", "AdditionalContent_deploy"];
func.dependencies = ["ArtcryptionMarketplace"];
