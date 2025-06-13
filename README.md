# CoinReal - 区块链社交活动管理平台

## 项目概览

CoinReal是一个基于以太坊的去中心化社交活动管理平台，专门为加密货币社区设计。用户可以注册账户、参与话题讨论、创建和参与活动Campaign，并通过互动获得代币奖励。

## 核心特性

### 🔐 用户系统
- 用户注册与资料管理
- 基于钱包地址的去中心化身份认证
- 用户权限管理

### 💬 话题讨论
- 创建和管理加密货币相关话题
- 用户评论与互动
- 点赞系统
- 实时价格追踪集成

### 🎯 Campaign系统
- 赞助商创建主题活动
- 基于ERC20的代币奖励机制
- 自动化奖励分发
- Campaign生命周期管理

### 💰 代币经济
- 评论奖励：10个代币/条评论
- 点赞奖励：5个代币/次点赞
- 多代币支持（USDC、ProjectToken）

## 技术架构

### 智能合约架构

```
├── src/
│   ├── core/                    # 核心业务逻辑
│   │   ├── App.sol             # 主合约 (16,785字节) ✅
│   │   ├── UserManager.sol     # 用户管理
│   │   ├── TopicManager.sol    # 话题与Campaign管理
│   │   ├── TopicBaseManager.sol # 话题基础功能
│   │   └── ActionManager.sol   # 用户行为管理
│   └── token/                   # 代币相关
│       ├── CampaignFactory.sol # Campaign工厂合约
│       ├── Campaign.sol        # Campaign代币合约
│       ├── ProjectToken.sol    # 项目代币
│       └── USDC.sol           # 稳定币
```

### 架构设计亮点

1. **组合模式设计** - App合约通过组合而非继承的方式使用各Manager合约，成功解决了合约大小超限问题
2. **模块化架构** - 各功能模块独立部署，便于升级和维护
3. **合约大小优化** - 从32,835字节优化到16,785字节，节省49%空间
4. **Gas优化** - 通过合理的数据结构和函数设计减少Gas消耗

## 部署指南

### 环境准备

```bash
# 安装依赖
git clone <repository-url>
cd CoinReal_0610
forge install

# 设置环境变量
echo "PRIVATE_KEY=你的私钥" > .env
```

### 本地测试网部署

```bash
# 启动本地测试网
anvil &

# 基础部署（仅合约）
forge script script/deployApp.s.sol --rpc-url http://localhost:8545 --broadcast

# 完整部署（包含测试数据）
forge script script/deployAppWithFakeData.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 合约验证

```bash
# 检查合约大小
forge build --sizes

# 运行测试
forge test
```

## 测试数据说明

部署脚本包含完整的测试数据集：

### 测试用户 (8个)
- Alice - 区块链爱好者
- Bob - 加密货币交易员  
- Charlie - DeFi开发者
- Diana - NFT收藏家
- Eve - Web3研究员
- BitcoinSponsor - Bitcoin投资机构
- EthereumSponsor - Ethereum基金会
- Admin - 系统管理员

### 测试话题 (5个)
- Bitcoin ($67,000)
- Ethereum ($3,500)  
- Solana ($150)
- Doge ($1)
- XRP ($1)

### 测试Campaign (2个)
- Bitcoin牛市预测活动
- 以太坊2.0升级讨论

### 测试互动数据
- 10条用户评论
- 14次点赞互动

## API接口

### 用户管理
```solidity
function registerUser(string memory _name, string memory _bio, string memory _email) external
function updateUser(string memory _name, string memory _bio, string memory _email) external  
function getUser(address _user) external view returns (User memory)
```

### 话题管理
```solidity
function registerTopic(string memory _name, string memory _description, string memory _tokenAddress, uint _tokenPrice) external
function commentOnTopic(uint _topicId, string memory _content) external
function likeComment(uint _commentId) external
```

### Campaign管理
```solidity
function registerCampaign(address _sponsor, uint _topicId, string memory _name, string memory _description) external returns (bool, uint)
function startCampaign(uint _campaignId, uint _duration) external
function endCampaign(uint _campaignId) external
```

## 合约地址（本地测试网）

最新部署地址请查看 `broadcast/` 目录下的部署记录。

## 性能指标

### 合约大小优化
- **App合约**: 16,785字节 (限制24,576字节)
- **剩余空间**: 7,791字节 (31.7%可扩展空间)
- **优化幅度**: 节省49%空间

### Gas消耗
- **用户注册**: ~100,000 gas
- **发布评论**: ~80,000 gas  
- **点赞操作**: ~60,000 gas
- **创建话题**: ~120,000 gas

## 已完成功能 ✅

- [x] 用户注册与管理系统
- [x] 话题创建与讨论功能
- [x] 评论与点赞系统
- [x] Campaign创建与管理
- [x] 代币奖励机制
- [x] 合约大小优化（组合模式重构）
- [x] 完整的部署脚本
- [x] 测试数据生成

## 待完成功能 🚧

### Chainlink集成
- [ ] **价格预言机集成** - 使用Chainlink Price Feeds自动更新代币价格
- [ ] **自动化执行** - 使用Chainlink Automation定时执行Campaign相关任务
- [ ] **VRF随机数** - 为抽奖活动提供可验证的随机数
- [ ] **跨链功能** - 使用Chainlink CCIP实现跨链资产转移

### 智能合约增强
- [ ] **Campaign自动结束机制** - 基于价格变动的智能触发
- [ ] **动态奖励算法** - 根据市场活跃度调整奖励
- [ ] **NFT徽章系统** - 为活跃用户发放成就NFT
- [ ] **质押挖矿功能** - 用户质押代币获得额外奖励

### 测试与安全
- [ ] **全面单元测试** - 覆盖所有智能合约功能
- [ ] **集成测试** - 测试Chainlink服务集成
- [ ] **安全审计** - 第三方安全审计
- [ ] **前端界面** - Web3 DApp用户界面

### 部署与运维
- [ ] **主网部署** - 以太坊主网部署计划
- [ ] **多链支持** - Polygon、BSC等侧链支持
- [ ] **监控系统** - 合约状态监控与告警
- [ ] **升级机制** - 可升级合约架构

## 开发团队

本项目专注于区块链社交活动管理，为加密货币社区提供完整的互动和激励解决方案。

## 许可证

MIT License

---

**注意**: 本项目目前处于开发阶段，请勿在生产环境中使用。所有合约均未经过安全审计。
