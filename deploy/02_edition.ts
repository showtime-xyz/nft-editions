module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const sharedNFTLogicAddress = (await deployments.get("SharedNFTLogic")).address;

  await deploy("Edition", {
    from: deployer,
    args: [
      sharedNFTLogicAddress
    ],
    log: true,
  });
};
module.exports.tags = ["Edition"];
module.exports.dependencies = ["SharedNFTLogic"]
