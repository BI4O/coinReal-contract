// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ITopicItem.sol";
import "../../token/interfaces/IUSDC.sol";
import "../../token/interfaces/ICampaignFactory.sol";

/**
 * @title ITopicManager
 * @notice 话题管理接口，继承自ITopicItem
 */
interface ITopicManager is ITopicItem {
    // 活动信息结构体
    struct CampaignInfo {
        // 创建参数
        uint id;            // 活动id：主键，0开始，每次注册+1
        address sponsor;    // 活动赞助商
        uint topicId;       // 话题id：外键
        string name;        // 活动名称
        string description; // 活动描述
        address projectTokenAddr; // 项目代币地址

        // 非创建参数
        bool isActive;      // 活动是否激活
        uint startTime;     // 活动开始时间
        uint endTime;       // 活动结束时间
        uint jackpot;       // 奖金池(美元计价)
        uint mintTokenAmount; // 活动期间mint的token数量(decimal 18)
        uint rewardUsdcPerMillionCPToken; // 每个CP token的得多少颗USDC
        uint rewardPtokenPerMillionCPToken; // 每个CP token的奖励
    }

    // 查询函数
    function owner() external view returns (address);
    function usdc() external view returns (IUSDC);
    function campaignFactory() external view returns (ICampaignFactory);
    function nextCampaignId() external view returns (uint);
    function MAX_CAMPAIGNS_PER_TOPIC() external view returns (uint);
    function campaigns(uint campaignId) external view returns (address);
    function topicCampaigns(uint topicId, uint index) external view returns (uint);
    function campaignInfos(uint campaignId) external view returns (CampaignInfo memory);
    function platformFeePercent() external view returns (uint);
    function qualityCommenterFeePercent() external view returns (uint);
    function lotteryForLikerFeePercent() external view returns (uint);
    function qualityCommenterNum() external view returns (uint);

    // 管理功能
    function setActionManager(address _actionManagerAddr) external;
    function setOwner(address _owner) external;

    // 活动操作
    function registerCampaign(address _sponsor, uint _topicId, string memory _name, string memory _description, address _projectTokenAddr) external returns (bool, uint);
    function fundCampaignWithUSDC(uint _campaignId, uint _amount) external;
    function fundCampaignWithProjectToken(uint _campaignId, uint _amount) external;
    function campaignNeedFundInUSD(uint _campaignId) external view returns (int);
    function checkCampaignCanStart(uint _campaignId) external view returns (bool);
    function startCampaign(uint _campaignId, uint _endTime) external;
    function endCampaign(uint _campaignId) external;
    function deleteTopic(uint _topicId) external;

    // 查询功能
    function getCampaignInfo(uint _campaignId) external view returns (CampaignInfo memory);
    function getCampaignsByTopic(uint _topicId) external view returns (uint[] memory);
    function getCampaignAddress(uint _campaignId) external view returns (address);
    function withdrawPlatformFee(uint _campaignId) external;
    function getRewardDistributionInfo(uint _campaignId) external view returns (address[] memory topCommenters, address[] memory luckyLikers, bool distributed);
} 