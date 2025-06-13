# CoinReal 架构文档

## 给下一个AI助手的信息

### 项目状态概览
- ✅ **合约大小问题已解决** - App合约从32KB优化到16.7KB
- ✅ **用户注册bug已修复** - 用户地址传递问题已解决
- ✅ **架构重构完成** - 从继承模式改为组合模式
- ✅ **部署脚本完善** - 包含完整测试数据

### 核心技术决策

1. **组合模式 vs 继承模式**
   - 原因：继承导致App合约超出24KB限制
   - 解决：App合约通过状态变量引用各Manager合约
   - 结果：合约大小减少49%

2. **TopicManager设计简化**
   - 发现：TopicManager已继承TopicBaseManager
   - 优化：移除App中对TopicBaseManager的冗余引用
   - 效果：避免数据隔离，简化架构

3. **用户地址传递修复**
   - 问题：UserManager使用msg.sender，但App调用时msg.sender是App地址
   - 解决：修改UserManager函数增加address参数
   - 修复：`_registerUser(address _user, ...)` 和 `_updateUser(address _user, ...)`

## 合约架构图

```
App.sol (16,785字节)
├── UserManager.sol (5,780字节)
├── TopicManager.sol (18,148字节)
│   └── 继承 TopicBaseManager.sol (8,593字节)
└── ActionManager.sol (6,062字节)

支持合约:
├── CampaignFactory.sol (1,726字节)
├── Campaign.sol (10,486字节)
├── ProjectToken.sol (4,460字节)
└── USDC.sol (4,101字节)
```

## 数据流架构

### 用户注册流程
```
用户 → App.registerUser() → UserManager._registerUser(用户地址, 用户信息)
```

### 评论发布流程
```
用户 → App.commentOnTopic() → ActionManager._addComment() + TopicManager.mint()
```

### Campaign创建流程
```
管理员 → App.registerCampaign() → TopicManager._registerCampaign() → CampaignFactory.createCampaign()
```

## 关键文件说明

### 核心合约
- `src/core/App.sol` - 主合约，所有external接口
- `src/core/UserManager.sol` - 用户CRUD操作
- `src/core/TopicManager.sol` - 话题和Campaign管理（继承TopicBaseManager）
- `src/core/ActionManager.sol` - 评论和点赞管理

### 部署脚本
- `script/deployApp.s.sol` - 基础部署（仅合约）
- `script/deployAppWithFakeData.s.sol` - 完整部署（含测试数据）
- `script/debugApp.s.sol` - 调试脚本

### 已知问题和注意事项
1. **TopicBaseManager冗余** - 已解决，App不再直接引用
2. **用户地址传递** - 已修复，UserManager正确接收用户地址
3. **合约大小限制** - 已解决，当前还有7KB扩展空间
4. **Campaign数据访问** - TopicManager能正确访问话题数据

## 下一步Chainlink集成计划

### 优先级1：价格预言机
- 集成Chainlink Price Feeds
- 自动更新话题中的代币价格
- 目标文件：`src/core/TopicManager.sol`

### 优先级2：自动化执行
- 使用Chainlink Automation
- 自动结束过期Campaign
- 基于价格变化触发事件

### 优先级3：VRF随机数
- 为抽奖活动添加随机数
- 增强Campaign功能

### 优先级4：跨链功能
- 使用Chainlink CCIP
- 实现多链资产转移

## 测试建议

### 单元测试重点
1. 用户注册和管理功能
2. 话题创建和价格更新
3. Campaign生命周期管理
4. 代币奖励分发机制
5. 权限控制和安全检查

### 集成测试重点
1. Chainlink Price Feeds集成
2. 跨合约调用流程
3. 代币mint和transfer
4. 完整的用户交互流程

## 开发环境
- Foundry框架
- Solidity ^0.8.20
- 本地测试网：Anvil
- 包管理：通过git submodules

## 重要提醒
- 所有Manager合约的internal函数已改为public
- App合约构造函数参数：(userManager, topicManager, actionManager, admin)
- 部署前确保anvil在运行：`anvil &`
- 使用环境变量PRIVATE_KEY进行部署 