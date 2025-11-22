// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
/// @dev 轻量接口，模拟 Chainlink Aggregator V3，按最新轮返回价格与精度
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

/// @title 可升级的 NFT 拍卖合约（支持 ETH/ERC20 出价，按 USD 统一比较）
/// @notice 使用 UUPS 升级模式，结合 Chainlink 喂价将出价转换为美元，比较不同币种出价
contract NFTAuctionUpgradeable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /// @notice 拍卖明细结构体
    struct Auction {
        /// @notice 被拍卖的 NFT 合约地址
        address nft;
        /// @notice 被拍卖的 TokenId
        uint256 tokenId;
        /// @notice 卖家地址（拥有该 NFT）
        address seller;
        /// @notice 起拍价（统一使用 18 位 USD 精度）
        uint256 minBidUSD18;
        /// @notice 开始时间戳
        uint256 startTime;
        /// @notice 持续时长（秒）
        uint256 duration;
        /// @notice 当前最高出价者
        address highestBidder;
        /// @notice 当前最高出价的 USD 数额（18 位精度）
        uint256 highestBidUSD18;
        /// @notice 当前最高出价使用的支付 Token（`address(0)` 表示 ETH）
        address paymentToken;
        /// @notice 当前最高出价的原始币种金额（wei 或 ERC20 最小单位）
        uint256 highestBidAmount;
        /// @notice 是否已结束（到期并已结算）
        bool ended;
        /// @notice 是否已取消（仅在无出价时允许）
        bool canceled;
    }

    /// @notice 拍卖列表（自增 ID → 拍卖明细）
    mapping(uint256 => Auction) public auctions;
    /// @notice 下一个拍卖 ID（自增计数器）
    uint256 private nextAuctionId;

    /// @notice ETH 拉式退款账本（被超越出价者 → 可提现 ETH 数额）
    mapping(address => uint256) public pendingReturnsEth;
    /// @notice ERC20 拉式退款账本（token → 被超越出价者 → 可提现 ERC20 数额）
    mapping(address => mapping(address => uint256)) public pendingReturnsToken;

    /// @notice ETH/USD 喂价源
    AggregatorV3Interface public ethUsdFeed;
    /// @notice 每个 ERC20 对应的 USD 喂价源
    mapping(address => AggregatorV3Interface) public tokenUsdFeed;

    /// @notice 拍卖创建事件
    event AuctionCreated(uint256 indexed auctionId, address indexed nft, uint256 indexed tokenId, address seller, uint256 minBidUSD18, uint256 duration);
    /// @notice ETH 出价事件
    event BidEth(uint256 indexed auctionId, address indexed bidder, uint256 amountWei, uint256 amountUsd18);
    /// @notice ERC20 出价事件
    event BidToken(uint256 indexed auctionId, address indexed bidder, address indexed token, uint256 amount, uint256 amountUsd18);
    /// @notice 拍卖取消事件
    event AuctionCanceled(uint256 indexed auctionId);
    /// @notice 拍卖结束事件
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, address indexed paymentToken, uint256 amountRaw, uint256 amountUsd18);
    /// @notice 提现 ETH 事件
    event WithdrawEth(address indexed account, uint256 amount);
    /// @notice 提现 ERC20 事件
    event WithdrawToken(address indexed token, address indexed account, uint256 amount);

    /// @notice 初始化合约（UUPS 代理需调用）
    /// @param owner_ 初始所有者地址（用于升级与配置权限）
    /// @param ethFeed_ ETH/USD 喂价合约地址
    function initialize(address owner_, address ethFeed_) public initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        ethUsdFeed = AggregatorV3Interface(ethFeed_);
    }

    /// @dev UUPS 升级授权，仅所有者可升级实现
    /// @param newImplementation 新的实现合约地址
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice 更新 ETH/USD 喂价地址
    /// @param feed Chainlink Aggregator 地址
    function setEthUsdFeed(address feed) external onlyOwner {
        ethUsdFeed = AggregatorV3Interface(feed);
    }

    /// @notice 为某个 ERC20 设置 USD 喂价地址
    /// @param token ERC20 代币地址
    /// @param feed Chainlink Aggregator 地址
    function setTokenUsdFeed(address token, address feed) external onlyOwner {
        tokenUsdFeed[token] = AggregatorV3Interface(feed);
    }

    /// @notice 创建拍卖（必须是 NFT 当前持有人且已授权合约）
    /// @param nft NFT 合约地址
    /// @param tokenId NFT 的 TokenId
    /// @param minBidUSD18 起拍价（18 位 USD 精度）
    /// @param duration 拍卖时长（秒）
    function createAuction(address nft, uint256 tokenId, uint256 minBidUSD18, uint256 duration) external {
        require(minBidUSD18 > 0, "min USD invalid");
        require(duration >= 10, "duration too short");
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "not owner");
        require(IERC721(nft).getApproved(tokenId) == address(this) || IERC721(nft).isApprovedForAll(msg.sender, address(this)), "not approved");

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

    /// @notice 使用 ETH 出价，自动按喂价换算为 USD 比较
    /// @param auctionId 拍卖 ID
    function bidEth(uint256 auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(!a.canceled && !a.ended && a.seller != address(0), "invalid auction");
        require(block.timestamp < a.startTime + a.duration, "expired");
        require(address(ethUsdFeed) != address(0), "no eth feed");
        uint256 usd18 = _toUsd18(msg.value, ethUsdFeed, 18);
        require(usd18 >= a.minBidUSD18, "below min");
        require(usd18 > a.highestBidUSD18, "not highest");

        // 关键逻辑：拉式退款（避免直接转账导致 2300 gas 限制、重入等问题）
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

    /// @notice 使用某个 ERC20 出价，按对应喂价换算为 USD 比较
    /// @param auctionId 拍卖 ID
    /// @param token ERC20 代币地址
    /// @param amount 出价的代币数量（最小单位）
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

        // 关键逻辑：累计上一个最高出价者的退款余额（支持多次被超越累计）
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

    /// @notice 取消拍卖（仅卖家，在无任何出价时）
    /// @param auctionId 拍卖 ID
    function cancelAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.seller == msg.sender, "not seller");
        require(!a.canceled && !a.ended, "finalized");
        require(a.highestBidder == address(0), "has bid");
        a.canceled = true;
        emit AuctionCanceled(auctionId);
    }

    /// @notice 结束并结算拍卖（到期后任意人可调用）
    /// @param auctionId 拍卖 ID
    function endAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(!a.canceled && !a.ended && a.seller != address(0), "invalid auction");
        require(block.timestamp >= a.startTime + a.duration, "not ended");
        a.ended = true;
        if (a.highestBidder != address(0)) {
            // 关键逻辑：先转移 NFT，再支付卖家，确保资产与资金对应
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

    /// @notice 提取被超过出价累计的 ETH 退款
    function withdrawEth() external {
        uint256 amount = pendingReturnsEth[msg.sender];
        require(amount > 0, "nothing");
        pendingReturnsEth[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "withdraw failed");
        emit WithdrawEth(msg.sender, amount);
    }

    /// @notice 提取被超过出价累计的某个 ERC20 退款
    /// @param token ERC20 代币地址
    function withdrawToken(address token) external {
        uint256 amount = pendingReturnsToken[token][msg.sender];
        require(amount > 0, "nothing");
        pendingReturnsToken[token][msg.sender] = 0;
        require(IERC20(token).transfer(msg.sender, amount), "withdraw failed");
        emit WithdrawToken(token, msg.sender, amount);
    }

    /// @dev 将原始金额换算到 USD 18 精度：amount(18) * price(18) / 1e18
    /// @param amountRaw 原始金额（wei 或 token 最小单位）
    /// @param feed 对应 Chainlink 喂价（ETH 或某个 ERC20 → USD）
    /// @param amountDecimals 原始金额小数位（ETH 为 18，ERC20 读取其 decimals）
    /// @return usdAmount18 18 位精度的 USD 金额
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