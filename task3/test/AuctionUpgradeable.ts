import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFTAuctionUpgradeable", () => {
  const fmtUSD = (v: bigint) => ethers.formatUnits(v, 18);
  const deployFeed = async (dec: number, price: bigint) => {
    const F = await ethers.getContractFactory("MockAggregator");
    const f = await F.deploy(dec, price);
    await f.waitForDeployment();
    return f;
  };
  const deployProxyAuction = async (owner: string, ethFeed: string) => {
    const Impl = await ethers.getContractFactory("NFTAuctionUpgradeable");
    const impl = await Impl.deploy();
    await impl.waitForDeployment();
    const initData = impl.interface.encodeFunctionData("initialize", [owner, ethFeed]);
    const Proxy = await ethers.getContractFactory("contracts/proxy/ERC1967Proxy.sol:ERC1967Proxy");
    const proxy = await Proxy.deploy(await impl.getAddress(), initData);
    await proxy.waitForDeployment();
    return ethers.getContractAt("NFTAuctionUpgradeable", await proxy.getAddress());
  };
  const deployNFT = async (deployer: any) => {
    const N = await ethers.getContractFactory("DemoNFT");
    const n = await N.connect(deployer).deploy("DemoNFT", "DNFT");
    await n.waitForDeployment();
    return n;
  };
  const deployToken = async (dec = 18) => {
    const T = await ethers.getContractFactory("MockERC20");
    const t = await T.deploy(dec === 18 ? "USDToken" : "USDToken6", dec === 18 ? "USDT" : "USDT6", dec);
    await t.waitForDeployment();
    return t;
  };
  const mintAndApprove = async (nft: any, seller: any, proxyAddr: string) => {
    const expected = await nft.mint.staticCall(await seller.getAddress());
    await nft.mint(await seller.getAddress());
    await nft.connect(seller).setApprovalForAll(proxyAddr, true);
    return expected;
  };

  it("e2e mixed bids and settlement (console logs)", async () => {
    const [deployer, seller, b1, b2] = await ethers.getSigners();
    const nft = await deployNFT(deployer);
    const token = await deployToken(18);
    await token.connect(b1).mint(await b1.getAddress(), ethers.parseEther("200"));

    const ethFeed = await deployFeed(8, 2000n * 10n ** 8n);
    const erc20Feed = await deployFeed(8, 2n * 10n ** 8n);
    const auction = await deployProxyAuction(await deployer.getAddress(), await ethFeed.getAddress());
    await auction.connect(deployer).setTokenUsdFeed(await token.getAddress(), await erc20Feed.getAddress());

    const tokenId = await mintAndApprove(nft, seller, await auction.getAddress());
    const minUsd18 = ethers.parseEther("100");
    await auction.connect(seller).createAuction(await nft.getAddress(), tokenId, minUsd18, 60);
    console.log("created auction minUSD=", fmtUSD(minUsd18));

    await token.connect(b1).approve(await auction.getAddress(), ethers.parseEther("200"));
    await auction.connect(b1).bidToken(1, await token.getAddress(), ethers.parseEther("60"));
    let a = await auction.auctions(1);
    console.log("after token bid: bidder=", a.highestBidder, "usd=", fmtUSD(a.highestBidUSD18));

    await auction.connect(b2).bidEth(1, { value: ethers.parseEther("0.061") });
    a = await auction.auctions(1);
    console.log("after eth bid: bidder=", a.highestBidder, "usd=", fmtUSD(a.highestBidUSD18));

    const sellerBalBefore = await ethers.provider.getBalance(await seller.getAddress());
    await ethers.provider.send("evm_increaseTime", [120]);
    await ethers.provider.send("evm_mine", []);
    await auction.connect(b1).endAuction(1);
    const sellerBalAfter = await ethers.provider.getBalance(await seller.getAddress());
    console.log("settled: seller eth +", (sellerBalAfter - sellerBalBefore).toString());
    expect(await nft.ownerOf(Number(tokenId))).to.equal(await b2.getAddress());
  });

  it("refund and withdraw ETH (console logs)", async () => {
    const [deployer, seller, b1, b2] = await ethers.getSigners();
    const nft = await deployNFT(deployer);
    const ethFeed = await deployFeed(8, 2000n * 10n ** 8n);
    const auction = await deployProxyAuction(await deployer.getAddress(), await ethFeed.getAddress());
    const tokenId = await mintAndApprove(nft, seller, await auction.getAddress());
    await auction.connect(seller).createAuction(await nft.getAddress(), tokenId, ethers.parseEther("100"), 60);
    await auction.connect(b1).bidEth(1, { value: ethers.parseEther("0.05") });
    await auction.connect(b2).bidEth(1, { value: ethers.parseEther("0.06") });
    const before = await auction.pendingReturnsEth(await b1.getAddress());
    console.log("pending ETH before withdraw:", before.toString());
    await auction.connect(b1).withdrawEth();
    const after = await auction.pendingReturnsEth(await b1.getAddress());
    console.log("pending ETH after withdraw:", after.toString());
    expect(after).to.equal(0n);
  });

  it("refund and withdraw Token (console logs)", async () => {
    const [deployer, seller, b1, b2] = await ethers.getSigners();
    const nft = await deployNFT(deployer);
    const token = await deployToken(6);
    await token.connect(b1).mint(await b1.getAddress(), ethers.parseUnits("200", 6));
    await token.connect(b2).mint(await b2.getAddress(), ethers.parseUnits("200", 6));
    const ethFeed = await deployFeed(8, 2000n * 10n ** 8n);
    const erc20Feed = await deployFeed(8, 2n * 10n ** 8n);
    const auction = await deployProxyAuction(await deployer.getAddress(), await ethFeed.getAddress());
    await auction.connect(deployer).setTokenUsdFeed(await token.getAddress(), await erc20Feed.getAddress());
    const tokenId = await mintAndApprove(nft, seller, await auction.getAddress());
    await auction.connect(seller).createAuction(await nft.getAddress(), tokenId, ethers.parseEther("100"), 60);
    await token.connect(b1).approve(await auction.getAddress(), ethers.parseUnits("200", 6));
    await token.connect(b2).approve(await auction.getAddress(), ethers.parseUnits("200", 6));
    await auction.connect(b1).bidToken(1, await token.getAddress(), ethers.parseUnits("50", 6));
    await auction.connect(b2).bidToken(1, await token.getAddress(), ethers.parseUnits("60", 6));
    const before = await auction.pendingReturnsToken(await token.getAddress(), await b1.getAddress());
    console.log("pending Token before withdraw:", before.toString());
    await auction.connect(b1).withdrawToken(await token.getAddress());
    const after = await auction.pendingReturnsToken(await token.getAddress(), await b1.getAddress());
    console.log("pending Token after withdraw:", after.toString());
    expect(after).to.equal(0n);
  });
});