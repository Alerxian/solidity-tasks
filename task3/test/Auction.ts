import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFTAuction end-to-end", function () {
  it("ETH/ERC20 bids compared in USD and settle correctly", async function () {
    const [seller, bidder1, bidder2] = await ethers.getSigners();

    const ERC721 = await ethers.getContractFactory("DemoNFT");
    const nft = await ERC721.connect(seller).deploy("DemoNFT", "DNFT");
    await nft.waitForDeployment();

    const token = await (await ethers.getContractFactory("MockERC20")).deploy("USDToken", "USDT", 18);
    await token.waitForDeployment();
    await token.connect(bidder1).mint(await bidder1.getAddress(), ethers.parseEther("200"));

    const ethFeed = await (await ethers.getContractFactory("MockAggregator")).deploy(8, 2000n * 10n ** 8n);
    await ethFeed.waitForDeployment();
    const erc20Feed = await (await ethers.getContractFactory("MockAggregator")).deploy(8, 2n * 10n ** 8n);
    await erc20Feed.waitForDeployment();

    const Auction = await ethers.getContractFactory("NFTAuction");
    const auction = await Auction.connect(seller).deploy();
    await auction.waitForDeployment();
    await auction.connect(seller).setEthUsdFeed(await ethFeed.getAddress());
    await auction.connect(seller).setTokenUsdFeed(await token.getAddress(), await erc20Feed.getAddress());

    const tokenId = await nft.connect(seller).mint(await seller.getAddress());
    await nft.connect(seller).setApprovalForAll(await auction.getAddress(), true);

    const minUsd18 = ethers.parseEther("100");
    await auction.connect(seller).createAuction(await nft.getAddress(), tokenId, minUsd18, 60);

    await token.connect(bidder1).approve(await auction.getAddress(), ethers.parseEther("100"));
    await auction.connect(bidder1).bidToken(1, await token.getAddress(), ethers.parseEther("60"));

    await auction.connect(bidder2).bidEth(1, { value: ethers.parseEther("0.06") });

    const a = await auction.auctions(1);
    expect(a.highestBidder).to.equal(await bidder2.getAddress());
    expect(a.paymentToken).to.equal(ethers.ZeroAddress);

    await ethers.provider.send("evm_increaseTime", [120]);
    await ethers.provider.send("evm_mine", []);
    const sellerBalanceBefore = await ethers.provider.getBalance(await seller.getAddress());
    await auction.connect(bidder1).endAuction(1);
    const sellerBalanceAfter = await ethers.provider.getBalance(await seller.getAddress());
    expect(sellerBalanceAfter - sellerBalanceBefore).to.be.greaterThan(0n);
    expect(await nft.ownerOf(tokenId)).to.equal(await bidder2.getAddress());

    const pendingEth = await auction.pendingReturnsEth(await bidder1.getAddress());
    expect(pendingEth).to.equal(ethers.parseEther("0"));
    const pendingToken = await auction.pendingReturnsToken(await token.getAddress(), await bidder1.getAddress());
    expect(pendingToken).to.equal(ethers.parseEther("60"));
    await auction.connect(bidder1).withdrawToken(await token.getAddress());
    expect(await token.balanceOf(await bidder1.getAddress())).to.equal(ethers.parseEther("200"));
  });
});