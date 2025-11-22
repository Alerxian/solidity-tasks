# 开发文档

## 概览
- 合约：
  - `contracts/tokens/DemoNFT.sol` 基于 OpenZeppelin ERC721，支持铸造与安全转移
  - `contracts/NFTAuctionUpgradeable.sol` UUPS 可升级拍卖，支持 ETH/ERC20 出价，按 USD（18 位精度）统一比较
  - `contracts/NFTAuction.sol` 非升级版拍卖（演示版），同样支持 ETH/ERC20 与 USD 比较
  - `contracts/mocks/MockAggregator.sol` Chainlink Aggregator V3 的轻量 Mock
  - `contracts/tokens/MockERC20.sol` 简化 ERC20 代币用于测试
  - `contracts/proxy/ERC1967Proxy.sol` 封装 OZ 的 `ERC1967Proxy` 方便测试部署

## 环境与安装
- 需要 Node.js、pnpm、Hardhat
- 安装依赖：
  - 使用 pnpm
  - `pnpm add -D @openzeppelin/contracts @openzeppelin/contracts-upgradeable @chainlink/contracts hardhat-deploy`

## 编译
- 命令：`pnpm hardhat compile`
- 配置：`hardhat.config.ts` 指定 `solidity: 0.8.28`

## 部署与初始化
- 部署 DemoNFT：
  - 通过 Hardhat 脚本或交互部署 `DemoNFT`，初始化 `name`/`symbol`
  - 铸造：合约所有者调用 `mint(to)` 获得 `tokenId`
- 部署 UUPS 拍卖：
  - 部署实现 `NFTAuctionUpgradeable`
  - 通过 `ERC1967Proxy` 构造函数传入 `initialize(owner, ethFeed)` 的编码数据完成代理初始化
  - 设置 ERC20 喂价：`setTokenUsdFeed(token, feed)`

## 使用流程
- 授权与上架：
  - 卖家对 `tokenId` 调用 `approve(auctionProxy)` 或 `setApprovalForAll(auctionProxy, true)`
  - 调用 `createAuction(nft, tokenId, minBidUSD18, duration)` 创建拍卖
- 出价：
  - ETH：`bidEth(auctionId)`，合约按 `ethUsdFeed` 将 `msg.value` 换算为 USD 比较
  - ERC20：`bidToken(auctionId, token, amount)`，按 `tokenUsdFeed[token]` 换算为 USD 比较
  - 当新的出价超过当前最高价：
    - 旧最高出价者的金额累计到拉式退款账本
    - ETH 记入 `pendingReturnsEth[bidder]`，ERC20 记入 `pendingReturnsToken[token][bidder]`
- 结算：
  - 到期后调用 `endAuction(auctionId)`
  - 将 NFT 从卖家转给最高出价者，并按支付币种将款项转给卖家
- 退款提取：
  - ETH：`withdrawEth()`
  - ERC20：`withdrawToken(token)`

## 价格换算与喂价
- 换算函数：`_toUsd18(amountRaw, feed, amountDecimals)`
  - 公式：`amount(18) * price(18) / 1e18`
  - ETH 的 `amountDecimals=18`，ERC20 从 `IERC20Metadata.decimals()` 读取
- 喂价设置：
  - ETH/USD：`setEthUsdFeed(aggregatorAddress)`
  - Token/USD：`setTokenUsdFeed(token, aggregatorAddress)`
- Mock 示例：
  - `MockAggregator(decimals, initialPrice)`，`latestRoundData()` 返回价格与时间戳

## 升级（UUPS）
- 角色：仅合约所有者可升级实现
- 步骤：
  - 部署新的实现合约
  - 通过代理地址调用 `upgradeTo(newImplementation)`（由 `onlyOwner` 授权的 `_authorizeUpgrade` 控制）
- 注意：升级前请确保存储布局兼容（不可打乱状态变量顺序）

## 事件
- `AuctionCreated(auctionId, nft, tokenId, seller, minBidUSD18, duration)`
- `BidEth(auctionId, bidder, amountWei, amountUsd18)`
- `BidToken(auctionId, bidder, token, amount, amountUsd18)`
- `AuctionCanceled(auctionId)`
- `AuctionEnded(auctionId, winner, paymentToken, amountRaw, amountUsd18)`
- `WithdrawEth(account, amount)`
- `WithdrawToken(token, account, amount)`

## 安全与设计
- 使用拉式退款（Pull Payment）避免直接转账导致的 gas 限制与重入风险
- 严格的权限与状态校验：
  - 上架必须为当前持有人且提前授权
  - 撤销仅在无出价时允许，且仅卖家可撤销
  - 结束必须到期且未取消
- 价格换算统一到 `USD 18` 精度，实现不同币种出价的公平比较

## 测试
- 端到端测试示例：`test/AuctionUpgradeable.ts`
- 运行命令：`pnpm hardhat test test/AuctionUpgradeable.ts`
- 覆盖流程：部署代理、设置喂价、ERC20/ETH 混合出价、结算与退款提取

## 常见问题
- 多重 Artifact 名称冲突：使用全限定名，例如 `@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy`
- Chainlink 接口路径：本项目内置轻量接口与 Mock，避免包路径差异导致的编译问题
- npm 依赖冲突：项目使用 `ethers@6` 与 `@nomicfoundation/hardhat-ethers`，避免同时安装 `@nomiclabs/hardhat-ethers`（针对 ethers v5）