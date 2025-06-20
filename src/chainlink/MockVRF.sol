// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ICampaignLotteryVRF.sol";

/**
 * @title MockVRF
 * @dev Mock implementation of ICampaignLotteryVRF for testing purposes
 * Based on Chainlink VRF v2.5 interface
 */
contract MockVRF is ICampaignLotteryVRF {
    // 存储结构
    struct CampaignLottery {
        bool isRequested;
        bool fulfilled;
        uint256 maxRange;
        uint256 count;
        uint256[] luckyIds;
    }
    
    mapping(uint256 => CampaignLottery) private _campaignLotteries;
    uint256 private nonce;
    
    // 模拟配置参数
    uint32 private _callbackGasLimit = 100000;
    uint16 private _requestConfirmations = 3;
    address private _linkAddress = address(0);
    address private _wrapperAddress = address(0);
    
    /**
     * @dev 为指定活动请求抽奖
     */
    function setLotteryByCampaignId(
        uint256 campaignId,
        uint256 maxRange,
        uint256 count,
        bool /* enableNativePayment */
    ) external override {
        require(maxRange > 0, "Invalid range");
        require(count > 0 && count <= maxRange, "Invalid count");
        require(!_campaignLotteries[campaignId].isRequested, "Lottery already requested");
        
        _campaignLotteries[campaignId].isRequested = true;
        _campaignLotteries[campaignId].maxRange = maxRange;
        _campaignLotteries[campaignId].count = count;
        
        emit LotteryRequested(campaignId, uint32(count), maxRange, count);
        
        // 立即生成随机数并完成抽奖
        _fulfillRandomness(campaignId);
    }
    
    /**
     * @dev 获取活动的幸运ID列表
     */
    function getCampaignLuckyIds(uint256 campaignId)
        external
        view
        override
        returns (
            bool isRequested,
            bool fulfilled,
            uint256[] memory luckyIds
        )
    {
        CampaignLottery memory lottery = _campaignLotteries[campaignId];
        return (lottery.isRequested, lottery.fulfilled, lottery.luckyIds);
    }
    
    /**
     * @dev 重置指定活动的抽奖数据
     */
    function resetVRF(uint256 campaignId) external override {
        delete _campaignLotteries[campaignId];
        emit LotteryReset(campaignId);
    }
    
    /**
     * @dev 批量重置多个活动的抽奖数据
     */
    function batchResetVRF(uint256[] calldata campaignIds) external override {
        for (uint256 i = 0; i < campaignIds.length; i++) {
            delete _campaignLotteries[campaignIds[i]];
            emit LotteryReset(campaignIds[i]);
        }
    }
    
    /**
     * @dev 重置所有活动的抽奖数据
     */
    function resetAllVRF(string calldata confirmationCode) external pure override {
        require(
            keccak256(abi.encodePacked(confirmationCode)) == 
            keccak256(abi.encodePacked("RESET_ALL_VRF_DATA")),
            "Invalid confirmation code"
        );
        // 在真实场景中会清除所有数据，这里不做实际操作
        // 因为mapping无法直接清除所有数据
    }
    
    /**
     * @dev 提取合约中剩余的LINK代币
     */
    function withdrawLink() external override {
        // 模拟函数，不做实际操作
        // 在真实合约中会提取LINK代币
    }
    
    /**
     * @dev 提取合约中剩余的原生代币(ETH)
     */
    function withdrawNative(uint256 amount) external pure override {
        // 模拟函数，不做实际操作
        // 在真实合约中会提取ETH
        require(amount > 0, "Amount must be greater than 0");
    }
    
    /**
     * @dev 查询活动抽奖信息
     */
    function campaignLotteries(uint256 campaignId) 
        external 
        view 
        override
        returns (
            bool isRequested,
            bool fulfilled,
            uint256 maxRange,
            uint256 count,
            uint256[] memory luckyIds
        )
    {
        CampaignLottery memory lottery = _campaignLotteries[campaignId];
        return (
            lottery.isRequested,
            lottery.fulfilled,
            lottery.maxRange,
            lottery.count,
            lottery.luckyIds
        );
    }
    
    /**
     * @dev 获取回调函数的gas限制
     */
    function callbackGasLimit() external view override returns (uint32) {
        return _callbackGasLimit;
    }
    
    /**
     * @dev 获取确认区块数
     */
    function requestConfirmations() external view override returns (uint16) {
        return _requestConfirmations;
    }
    
    /**
     * @dev 获取LINK代币地址
     */
    function linkAddress() external view override returns (address) {
        return _linkAddress;
    }
    
    /**
     * @dev 获取VRF Wrapper地址
     */
    function wrapperAddress() external view override returns (address) {
        return _wrapperAddress;
    }
    
    /**
     * @dev 内部函数，生成随机数并完成抽奖
     */
    function _fulfillRandomness(uint256 campaignId) internal {
        CampaignLottery storage lottery = _campaignLotteries[campaignId];
        uint256 maxRange = lottery.maxRange;
        uint256 count = lottery.count;
        
        // 生成不重复的随机数
        uint256[] memory luckyIds = new uint256[](count);
        uint256[] memory pool = new uint256[](maxRange);
        
        // 初始化池
        for (uint256 i = 0; i < maxRange; i++) {
            pool[i] = i;
        }
        
        // 随机选择
        for (uint256 i = 0; i < count; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,
                campaignId,
                i,
                nonce++
            ))) % (maxRange - i);
            
            luckyIds[i] = pool[randomIndex];
            
            // 将最后一个元素移到已选位置
            pool[randomIndex] = pool[maxRange - i - 1];
        }
        
        // 存储结果
        lottery.luckyIds = luckyIds;
        lottery.fulfilled = true;
        
        emit LotteryCompleted(campaignId, luckyIds);
    }
    
    /**
     * @dev 设置配置参数（仅用于测试）
     */
    function setCallbackGasLimit(uint32 _gasLimit) external {
        _callbackGasLimit = _gasLimit;
    }
    
    function setRequestConfirmations(uint16 _confirmations) external {
        _requestConfirmations = _confirmations;
    }
    
    function setLinkAddress(address _link) external {
        _linkAddress = _link;
    }
    
    function setWrapperAddress(address _wrapper) external {
        _wrapperAddress = _wrapper;
    }
    
    /**
     * @dev 接收ETH
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
} 