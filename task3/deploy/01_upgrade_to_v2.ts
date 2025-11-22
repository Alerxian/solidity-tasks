import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxy = await get("NFTAuctionUpgradeable");

  const implV2 = await deploy("NFTAuctionUpgradeableV2_Implementation", {
    contract: "NFTAuctionUpgradeableV2",
    from: deployer,
    log: true,
  });

  const signer = await ethers.getSigner(deployer);
  const iface = new ethers.Interface([
    "function upgradeTo(address newImplementation)",
    "function upgradeToAndCall(address newImplementation, bytes data)"
  ]);
  const proxyAsUUPS = new ethers.Contract(proxy.address, iface, signer);
  let tx;
  try {
    tx = await proxyAsUUPS.upgradeTo(implV2.address);
  } catch {
    tx = await proxyAsUUPS.upgradeToAndCall(implV2.address, "0x");
  }
  await tx.wait();
  log(`Upgraded proxy ${proxy.address} to V2 implementation ${implV2.address}`);

  const v2 = await ethers.getContractAt("NFTAuctionUpgradeableV2", proxy.address);
  const hello = await v2.sayHello();
  log(`sayHello() => ${hello}`);
};

export default func;
func.tags = ["UpgradeV2"];
func.dependencies = ["AuctionUpgradeable"];