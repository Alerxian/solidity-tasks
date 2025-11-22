import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const ethFeed = await deploy("MockAggregator", {
    from: deployer,
    args: [8, 2000n * 10n ** 8n],
    log: true,
  });

  const impl = await deploy("NFTAuctionUpgradeable_Implementation", {
    contract: "NFTAuctionUpgradeable",
    from: deployer,
    log: true,
  });

  const ImplFactory = await ethers.getContractFactory("NFTAuctionUpgradeable");
  const initData = ImplFactory.interface.encodeFunctionData("initialize", [deployer, ethFeed.address]);

  const proxy = await deploy("NFTAuctionUpgradeable", {
    contract: "contracts/proxy/ERC1967Proxy.sol:ERC1967Proxy",
    from: deployer,
    args: [impl.address, initData],
    log: true,
  });

  log(`NFTAuctionUpgradeable implementation at ${impl.address}`);
  log(`NFTAuctionUpgradeable proxy at ${proxy.address}`);
};

export default func;
func.tags = ["AuctionUpgradeable"];