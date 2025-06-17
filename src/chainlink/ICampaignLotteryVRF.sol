// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title ICampaignLotteryVRF
 * @dev CampaignLotteryVRF合约的接口定义
 * 部署在Sepolia测试网: 0xd5916F5ea735431384A66FF0F0aa09f26A3f8E04
 */
interface ICampaignLotteryVRF {
    /**
     * @dev 抽奖请求事件
     */
    event LotteryRequested(uint256 campaignId, uint32 numWords, uint256 maxRange, uint256 count);
    
    /**
     * @dev 抽奖完成事件
     */
    event LotteryCompleted(uint256 campaignId, uint256[] luckyIds);
    
    /**
     * @dev 抽奖重置事件
     */
    event LotteryReset(uint256 campaignId);
    
    /**
     * @dev 接收ETH事件
     */
    event Received(address sender, uint256 amount);
    
    /**
     * @dev 为指定活动请求抽奖
     * @param campaignId 活动ID
     * @param maxRange 随机数范围上限（从0到maxRange-1）
     * @param count 需要选择的幸运者数量
     * @param enableNativePayment 是否使用原生代币支付（true为ETH，false为LINK）
     */
    function setLotteryByCampaignId(
        uint256 campaignId,
        uint256 maxRange,
        uint256 count,
        bool enableNativePayment
    ) external;
    
    /**
     * @dev 获取活动的幸运ID列表
     * @param campaignId 活动ID
     * @return isRequested 是否已请求抽奖
     * @return fulfilled 抽奖是否已完成
     * @return luckyIds 幸运ID列表
     */
    function getCampaignLuckyIds(uint256 campaignId)
        external
        view
        returns (
            bool isRequested,
            bool fulfilled,
            uint256[] memory luckyIds
        );
    
    /**
     * @dev 重置指定活动的抽奖数据
     * @param campaignId 活动ID
     */
    function resetVRF(uint256 campaignId) external;
    
    /**
     * @dev 批量重置多个活动的抽奖数据
     * @param campaignIds 活动ID数组
     */
    function batchResetVRF(uint256[] calldata campaignIds) external;
    
    /**
     * @dev 重置所有活动的抽奖数据（危险操作，谨慎使用）
     * @param confirmationCode 确认代码，必须为"RESET_ALL_VRF_DATA"
     */
    function resetAllVRF(string calldata confirmationCode) external;
    
    /**
     * @dev 提取合约中剩余的LINK代币
     */
    function withdrawLink() external;
    
    /**
     * @dev 提取合约中剩余的原生代币(ETH)
     * @param amount 提取金额，单位为wei
     */
    function withdrawNative(uint256 amount) external;
    
    /**
     * @dev 查询活动抽奖信息
     * @param campaignId 活动ID
     * @return 返回活动抽奖信息结构体
     */
    function campaignLotteries(uint256 campaignId) 
        external 
        view 
        returns (
            bool isRequested,
            bool fulfilled,
            uint256 maxRange,
            uint256 count,
            uint256[] memory luckyIds
        );
    
    /**
     * @dev 获取回调函数的gas限制
     */
    function callbackGasLimit() external view returns (uint32);
    
    /**
     * @dev 获取确认区块数
     */
    function requestConfirmations() external view returns (uint16);
    
    /**
     * @dev 获取LINK代币地址
     */
    function linkAddress() external view returns (address);
    
    /**
     * @dev 获取VRF Wrapper地址
     */
    function wrapperAddress() external view returns (address);
} 