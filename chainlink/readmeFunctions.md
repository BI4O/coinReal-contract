# Chainlink Functions 评论情感分析系统

本目录包含基于Chainlink Functions实现的评论情感分析系统合约。

## CommentSentimentAnalyzer

`CommentSentimentAnalyzer`是一个基于Chainlink Functions和Gemini AI实现的评论情感分析合约，支持对评论进行自动情感分析并返回POS（积极）、NEG（消极）或NEU（中性）标签。

### 已部署合约

合约已部署在Sepolia测试网上：
- 地址：`0x8a000e20bEc0c5627B5898376A8f6FEfCf79baC9`
- Owner：`0x802f71cBf691D4623374E8ec37e32e26d5f74d87`
- Chainlink Functions订阅ID：`5044`
- 当前余额：80个LINK代币

fuji测试网：
- 地址：`0x3d4AFaAd35E81C8Da51cf0bfC48f0E71C0BB8b2D`
- Owner：`0x802f71cBf691D4623374E8ec37e32e26d5f74d87`
- Chainlink Functions订阅ID：`15554`
- 当前余额：20个LINK代币

订阅信息：
sepolia：https://functions.chain.link/sepolia/5044
fuji：https://functions.chain.link/fuji/15554

### 主要功能

1. **情感分析**：通过`addTag`函数为指定评论进行AI情感分析。
2. **查询结果**：通过`getCommentTagById`函数查询评论的情感标签。
3. **重置功能**：支持重置单个评论、批量重置多个评论或重置所有评论的分析数据。
4. **配置管理**：支持更新gas限制等参数配置。

### 使用方法

#### 1. 在其他合约中使用

```solidity
// 导入接口
import "./ICommentAddTagFunctions.sol";

contract YourContract {
    // CommentSentimentAnalyzer合约接口
    ICommentAddTagFunctions public sentimentContract;
    
    // Chainlink Functions订阅ID
    uint64 constant SUBSCRIPTION_ID = 5044;
    
    constructor(address _sentimentContractAddress) {
        sentimentContract = ICommentAddTagFunctions(_sentimentContractAddress);
    }
    
    // 发起情感分析
    function analyzeComment(uint commentId, string memory comment) external {
        bytes32 requestId = sentimentContract.addTag(commentId, comment, SUBSCRIPTION_ID);
        // 存储requestId以便后续跟踪
    }
    
    // 查询分析结果
    function getCommentSentiment(uint commentId) external view returns (string memory) {
        require(sentimentContract.isAnalyzed(commentId), "Comment not analyzed yet");
        return sentimentContract.getCommentTagById(commentId);
    }
    
    // 检查是否已分析
    function isCommentAnalyzed(uint commentId) external view returns (bool) {
        return sentimentContract.isAnalyzed(commentId);
    }
}
```

#### 2. 直接与合约交互

可以通过ethers.js等库直接与合约交互：

```javascript
// 使用ethers.js
const { ethers } = require("ethers");
const sentimentAbi = require("./ICommentAddTagFunctions.json"); // 合约ABI

async function interactWithSentimentAnalyzer() {
    const provider = new ethers.providers.JsonRpcProvider("https://sepolia.infura.io/v3/YOUR_INFURA_KEY");
    const signer = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);
    
    // 连接到情感分析合约
    const sentimentContract = new ethers.Contract("0x8a000e20bEc0c5627B5898376A8f6FEfCf79baC9", sentimentAbi, signer);
    
    // 发起情感分析
    const commentId = 123;
    const comment = "Bitcoin is going to the moon! Great project!";
    const subscriptionId = 5044;
    
    const tx = await sentimentContract.addTag(commentId, comment, subscriptionId);
    await tx.wait();
    console.log("情感分析请求已发送");
    
    // 查询结果（需要等待Chainlink Functions响应）
    // 使用定时器或事件监听来检查结果
    const checkResult = async () => {
        const isAnalyzed = await sentimentContract.isAnalyzed(commentId);
        if (isAnalyzed) {
            const tag = await sentimentContract.getCommentTagById(commentId);
            console.log("情感分析结果:", tag); // POS, NEG, 或 NEU
        } else {
            console.log("分析中，请稍等...");
            setTimeout(checkResult, 5000); // 5秒后再检查
        }
    };
    
    setTimeout(checkResult, 10000); // 10秒后开始检查
}
```

#### 3. 事件监听

```javascript
// 监听分析完成事件
sentimentContract.on("TagAnalysisCompleted", (commentId, tag, requestId) => {
    console.log(`评论 ${commentId} 分析完成，结果: ${tag}`);
});

// 监听分析请求事件
sentimentContract.on("TagAnalysisRequested", (commentId, comment, requestId) => {
    console.log(`评论 ${commentId} 开始分析: ${comment}`);
});
```

### 注意事项

1. **权限管理**：只有合约Owner才能调用`addTag`、`resetCommentTag`等关键函数。
2. **异步处理**：Chainlink Functions是异步的，发起分析请求后需要等待一段时间（通常30秒到2分钟）才能获取结果。
3. **费用消耗**：每次调用`addTag`会消耗LINK代币，当前合约有80个LINK余额。
4. **结果类型**：返回的标签只有三种：`POS`（积极）、`NEG`（消极）、`NEU`（中性）。

### API参考

#### 核心函数

```solidity
// 发起情感分析
function addTag(uint commentId, string calldata comment, uint64 subscriptionId) external returns (bytes32 requestId);

// 获取分析结果
function getCommentTagById(uint commentId) external view returns (string memory tag);

// 检查是否已分析
function isAnalyzed(uint commentId) external view returns (bool analyzed);

// 获取评论内容
function getCommentContentById(uint commentId) external view returns (string memory comment);
```

#### 管理函数（仅Owner）

```solidity
// 重置单个评论
function resetCommentTag(uint commentId) external;

// 批量重置
function batchResetCommentTags(uint[] calldata commentIds) external;

// 重置所有数据
function resetAllTags(string calldata confirmationCode) external;

// 更新gas限制
function updateGasLimit(uint32 newGasLimit) external;
```

### 使用示例

#### 简单分析

```solidity
// 分析一条评论
uint commentId = 1;
string memory comment = "This crypto project is amazing!";
bytes32 requestId = sentimentAnalyzer.addTag(commentId, comment, 5044);

// 等待几分钟后查询结果
string memory result = sentimentAnalyzer.getCommentTagById(commentId);
// 结果可能是 "POS"
```

#### 批量分析

```solidity
// 批量分析多条评论
for (uint i = 1; i <= 10; i++) {
    string memory comment = getCommentById(i); // 假设这个函数存在
    sentimentAnalyzer.addTag(i, comment, 5044);
}

// 等待处理完成后批量查询结果
for (uint i = 1; i <= 10; i++) {
    if (sentimentAnalyzer.isAnalyzed(i)) {
        string memory tag = sentimentAnalyzer.getCommentTagById(i);
        processResult(i, tag); // 处理结果
    }
}
```

### 错误处理

常见错误及解决方案：

1. `"Comment already analyzed"` - 评论已经分析过，如需重新分析请先重置
2. `"Invalid subscription ID"` - 订阅ID无效，请使用正确的订阅ID: 5044
3. `"Comment not analyzed"` - 评论还未分析完成，请等待或检查是否分析失败

### 技术细节

- 使用Gemini 2.5 Flash模型进行情感分析
- Gas限制设置为300,000
- 支持Sepolia测试网
- 异步回调机制处理AI响应

