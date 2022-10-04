module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Edition", {
    from: deployer,
    args: [],
    log: true,
  });
};
module.exports.tags = ["Edition"];
module.exports.dependencies = []
