import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  await deploy("OwnershipCertificate", {
    from: deployer,
    contract: "OwnershipCertificate",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["OwnershipCertificate", "OwnershipCertificate_deploy"];
