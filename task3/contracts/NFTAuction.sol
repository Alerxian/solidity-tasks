// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

contract NFTAuction {
    struct Auction {
        address nft;
        uint256 tokenId;
        address seller;
        uint256 minBidUSD18;
        uint256 startTime;
        uint256 duration;
        address highestBidder;
        uint256 highestBidUSD18;
        address paymentToken;
        uint256 highestBidAmount;
        bool ended;
        bool canceled;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 private nextAuctionId;

    mapping(address => uint256) public pendingReturnsEth;
    mapping(address => mapping(address => uint256)) public pendingReturnsToken;

    address public owner;
    AggregatorV3Interface public ethUsdFeed;
    mapping(address => AggregatorV3Interface) public tokenUsdFeed;

    event AuctionCreated(uint256 indexed auctionId, address indexed nft, uint256 indexed tokenId, address seller, uint256 minBidUSD18, uint256 duration);
    event BidEth(uint256 indexed auctionId, address indexed bidder, uint256 amountWei, uint256 amountUsd18);
    event BidToken(uint256 indexed auctionId, address indexed bidder, address indexed token, uint256 amount, uint256 amountUsd18);
    event AuctionCanceled(uint256 indexed auctionId);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, address indexed paymentToken, uint256 amountRaw, uint256 amountUsd18);
    event WithdrawEth(address indexed account, uint256 amount);
    event WithdrawToken(address indexed token, address indexed account, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function setEthUsdFeed(address feed) external {
        require(msg.sender == owner, "not owner");
        ethUsdFeed = AggregatorV3Interface(feed);
    }

    function setTokenUsdFeed(address token, address feed) external {
        require(msg.sender == owner, "not owner");
        tokenUsdFeed[token] = AggregatorV3Interface(feed);
    }

    function createAuction(address nft, uint256 tokenId, uint256 minBidUSD18, uint256 duration) external {
        require(minBidUSD18 > 0, "min USD invalid");
        require(duration >= 10, "duration too short");
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "not owner");
        require(
            IERC721(nft).getApproved(tokenId) == address(this) || IERC721(nft).isApprovedForAll(msg.sender, address(this)),
            "not approved"
        );

        uint256 auctionId = ++nextAuctionId;
        auctions[auctionId] = Auction({
            nft: nft,
            tokenId: tokenId,
            seller: msg.sender,
            minBidUSD18: minBidUSD18,
            startTime: block.timestamp,
            duration: duration,
            highestBidder: address(0),
            highestBidUSD18: 0,
            paymentToken: address(0),
            highestBidAmount: 0,
            ended: false,
            canceled: false
        });

        emit AuctionCreated(auctionId, nft, tokenId, msg.sender, minBidUSD18, duration);
    }

    function bidEth(uint256 auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(!a.canceled && !a.ended && a.seller != address(0), "invalid auction");
        require(block.timestamp < a.startTime + a.duration, "expired");
        require(address(ethUsdFeed) != address(0), "no eth feed");
        uint256 usd18 = _toUsd18(msg.value, ethUsdFeed, 18);
        require(usd18 >= a.minBidUSD18, "below min");
        require(usd18 > a.highestBidUSD18, "not highest");

        if (a.highestBidder != address(0)) {
            if (a.paymentToken == address(0)) {
                pendingReturnsEth[a.highestBidder] += a.highestBidAmount;
            } else {
                pendingReturnsToken[a.paymentToken][a.highestBidder] += a.highestBidAmount;
            }
        }

        a.highestBidder = msg.sender;
        a.highestBidUSD18 = usd18;
        a.paymentToken = address(0);
        a.highestBidAmount = msg.value;
        emit BidEth(auctionId, msg.sender, msg.value, usd18);
    }

    function bidToken(uint256 auctionId, address token, uint256 amount) external {
        Auction storage a = auctions[auctionId];
        require(!a.canceled && !a.ended && a.seller != address(0), "invalid auction");
        require(block.timestamp < a.startTime + a.duration, "expired");
        require(address(tokenUsdFeed[token]) != address(0), "no token feed");
        require(amount > 0, "amount zero");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        uint8 tdec = IERC20Metadata(token).decimals();
        uint256 usd18 = _toUsd18(amount, tokenUsdFeed[token], tdec);
        require(usd18 >= a.minBidUSD18, "below min");
        require(usd18 > a.highestBidUSD18, "not highest");

        if (a.highestBidder != address(0)) {
            if (a.paymentToken == address(0)) {
                pendingReturnsEth[a.highestBidder] += a.highestBidAmount;
            } else {
                pendingReturnsToken[a.paymentToken][a.highestBidder] += a.highestBidAmount;
            }
        }

        a.highestBidder = msg.sender;
        a.highestBidUSD18 = usd18;
        a.paymentToken = token;
        a.highestBidAmount = amount;
        emit BidToken(auctionId, msg.sender, token, amount, usd18);
    }

    function cancelAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.seller == msg.sender, "not seller");
        require(!a.canceled && !a.ended, "finalized");
        require(a.highestBidder == address(0), "has bid");
        a.canceled = true;
        emit AuctionCanceled(auctionId);
    }

    function endAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(!a.canceled && !a.ended && a.seller != address(0), "invalid auction");
        require(block.timestamp >= a.startTime + a.duration, "not ended");
        a.ended = true;
        if (a.highestBidder != address(0)) {
            IERC721(a.nft).transferFrom(a.seller, a.highestBidder, a.tokenId);
            if (a.paymentToken == address(0)) {
                (bool ok, ) = payable(a.seller).call{value: a.highestBidAmount}("");
                require(ok, "pay seller failed");
            } else {
                require(IERC20(a.paymentToken).transfer(a.seller, a.highestBidAmount), "pay token failed");
            }
            emit AuctionEnded(auctionId, a.highestBidder, a.paymentToken, a.highestBidAmount, a.highestBidUSD18);
        } else {
            emit AuctionEnded(auctionId, address(0), address(0), 0, 0);
        }
    }

    function withdrawEth() external {
        uint256 amount = pendingReturnsEth[msg.sender];
        require(amount > 0, "nothing");
        pendingReturnsEth[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "withdraw failed");
        emit WithdrawEth(msg.sender, amount);
    }

    function withdrawToken(address token) external {
        uint256 amount = pendingReturnsToken[token][msg.sender];
        require(amount > 0, "nothing");
        pendingReturnsToken[token][msg.sender] = 0;
        require(IERC20(token).transfer(msg.sender, amount), "withdraw failed");
        emit WithdrawToken(token, msg.sender, amount);
    }

    function _toUsd18(uint256 amountRaw, AggregatorV3Interface feed, uint8 amountDecimals) internal view returns (uint256) {
        (, int256 price,,,) = feed.latestRoundData();
        require(price > 0, "bad price");
        uint8 pdec = feed.decimals();
        uint256 scale = 10 ** uint256(amountDecimals);
        uint256 pscale = 10 ** uint256(pdec);
        uint256 amount18 = (amountRaw * (10 ** (18))) / scale;
        uint256 price18 = (uint256(price) * (10 ** (18))) / pscale;
        return (amount18 * price18) / (10 ** 18);
    }
}
