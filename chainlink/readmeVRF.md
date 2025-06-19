# Chainlink VRF 抽奖系统

本目录包含基于Chainlink VRF v2.5实现的抽奖系统合约。

## CampaignLotteryVRF

`CampaignLotteryVRF`是一个基于Chainlink VRF v2.5实现的活动抽奖合约，支持从指定范围内随机选择不重复的幸运ID。

### 已部署合约

合约已部署在Sepolia测试网上：
- 地址：`0xd5916F5ea735431384A66FF0F0aa09f26A3f8E04`
- Owner：`0x802f71cBf691D4623374E8ec37e32e26d5f74d87`

### 主要功能

1. **发起抽奖**：通过`setLotteryByCampaignId`函数为指定活动发起抽奖。
2. **查询结果**：通过`getCampaignLuckyIds`函数查询活动的抽奖结果。
3. **重置功能**：支持重置单个活动、批量重置多个活动或重置所有活动的抽奖数据。
4. **资金管理**：支持提取合约中的LINK代币和ETH。

### 使用方法

#### 1. 在其他合约中使用

```solidity
// 导入接口
import "./ICampaignLotteryVRF.sol";

contract YourContract {
    // CampaignLotteryVRF合约接口
    ICampaignLotteryVRF public vrfContract;
    
    constructor(address _vrfContractAddress) {
        vrfContract = ICampaignLotteryVRF(_vrfContractAddress);
    }
    
    // 发起抽奖
    function startLottery(uint256 campaignId, uint256 maxRange, uint256 count) external {
        // 使用LINK代币支付
        vrfContract.setLotteryByCampaignId(campaignId, maxRange, count, false);
    }
    
    // 查询结果
    function checkResults(uint256 campaignId) external view returns (bool, bool, uint256[] memory) {
        return vrfContract.getCampaignLuckyIds(campaignId);
    }
}
```

#### 2. 直接与合约交互

可以通过ethers.js等库直接与合约交互：

```javascript
// 使用ethers.js
const { ethers } = require("ethers");
const vrfAbi = require("./ICampaignLotteryVRF.json"); // 合约ABI

async function interactWithVRF() {
    const provider = new ethers.providers.JsonRpcProvider("https://sepolia.infura.io/v3/YOUR_INFURA_KEY");
    const signer = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);
    
    // 连接到VRF合约
    const vrfContract = new ethers.Contract("0xd5916F5ea735431384A66FF0F0aa09f26A3f8E04", vrfAbi, signer);
    
    // 发起抽奖
    const campaignId = 123;
    const maxRange = 100; // 随机数范围0-99
    const count = 5;      // 选择5个幸运ID
    const useETH = true;  // 使用ETH支付
    
    const tx = await vrfContract.setLotteryByCampaignId(campaignId, maxRange, count, useETH);
    await tx.wait();
    console.log("抽奖请求已发送");
    
    // 查询结果（需要等待Chainlink VRF响应）
    const results = await vrfContract.getCampaignLuckyIds(campaignId);
    console.log("抽奖结果:", results);
}
```

### 注意事项

1. 只有合约Owner才能调用`setLotteryByCampaignId`、`resetVRF`等关键函数。
2. 使用ETH支付时，需要确保合约有足够的ETH余额。
3. 使用LINK支付时，需要确保合约有足够的LINK代币余额。
4. Chainlink VRF是异步的，发起抽奖请求后需要等待一段时间（通常几个区块）才能获取结果。

## MockVRF

`MockVRF`是一个简化的VRF模拟合约，主要用于本地测试。它提供了与真实Chainlink VRF类似的接口，但使用伪随机数生成器，不适合生产环境。

## PriceFeed

`PriceFeed`是一个Chainlink价格预言机的简单实现，用于获取资产价格数据。

## VRF使用方法

### 1. 请求抽奖

```solidity
// 为活动ID 5设置抽奖，从100个用户中选择3位幸运者，使用ETH支付
setLotteryByCampaignId(5, 100, 3, true);
```

### 2. 获取抽奖结果

```solidity
// 获取活动ID 5的抽奖结果
(bool isRequested, bool fulfilled, uint256[] memory luckyIds) = getCampaignLuckyIds(5);

// 检查抽奖是否已完成
if (fulfilled) {
    // 使用luckyIds数组中的幸运ID
}
```

### 3. 重置抽奖数据

```solidity
// 重置单个活动
resetVRF(5);

// 批量重置多个活动
uint256[] memory campaignIds = new uint256[](2);
campaignIds[0] = 5;
campaignIds[1] = 6;
batchResetVRF(campaignIds);

// 重置所有活动（谨慎使用）
resetAllVRF("RESET_ALL_VRF_DATA");
```