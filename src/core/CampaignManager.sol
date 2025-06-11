// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {CampaignFactory} from "../token/CampaignFactory.sol";
import {CampaignToken} from "../token/Campaign.sol";

contract CampaignManager {
    CampaignFactory public campaignFactory;
    
    // 活动信息管理 - 一对多关系
    uint public nextCampaignId;
    uint public constant MAX_CAMPAIGNS_PER_TOPIC = 3; // 每个topic最多3个campaign
    
    mapping(uint => address) public campaigns; // campaignId => tokenAddress
    mapping(uint => uint[]) public topicCampaigns; // topicId => campaignId[] (一对多)
    
    // Campaign状态管理
    struct CampaignInfo {
        bool isActive;
        uint startTime;
        uint endTime;
        uint budget;        // 总预算 (以token为单位)
        uint spentBudget;   // 已花费预算
    }
    mapping(uint => CampaignInfo) public campaignInfos;
    
    // mint奖励配置
    uint public commentReward = 10 * 1e18;  // 评论奖励10个token
    uint public likeReward = 5 * 1e18;      // 点赞奖励5个token

    // 设置factory
    function _setCampaignFactory(address _factory) internal {
        campaignFactory = CampaignFactory(_factory);
    }

    // 注册活动
    function _registerCampaign(
        address _sponsor,
        string memory _name,
        string memory /* _description */,
        uint _topicId,
        uint _budget,      // 总预算(以token为单位)
        uint _duration     // 活动持续时间(秒)
    ) internal {
        // 检查该topic的campaign数量限制
        require(topicCampaigns[_topicId].length < MAX_CAMPAIGNS_PER_TOPIC, "Topic campaign limit reached");
        
        // 通过factory创建campaign token
        address campaignToken = campaignFactory.createCampaignToken(
            _name,
            string(abi.encodePacked(_name, "Token")),
            _sponsor,
            address(this),  // 使用继承关系，this就是App合约
            _topicId
        );
        
        campaigns[nextCampaignId] = campaignToken;
        topicCampaigns[_topicId].push(nextCampaignId);
        
        // 设置campaign信息
        campaignInfos[nextCampaignId] = CampaignInfo({
            isActive: true,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            budget: _budget,
            spentBudget: 0
        });
        
        nextCampaignId++;
    }
    
    // 处理评论奖励
    function _handleCommentReward(uint _topicId, address _user) internal {
        uint[] memory campaignIds = topicCampaigns[_topicId];
        
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            
            if (_isCampaignValid(campaignId, commentReward)) {
                address campaignToken = campaigns[campaignId];
                CampaignToken(campaignToken).mint(_user, commentReward);
                
                // 更新已花费预算
                campaignInfos[campaignId].spentBudget += commentReward;
            }
        }
    }
    
    // 处理点赞奖励
    function _handleLikeReward(uint _topicId, address _user) internal {
        uint[] memory campaignIds = topicCampaigns[_topicId];
        
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            
            if (_isCampaignValid(campaignId, likeReward)) {
                address campaignToken = campaigns[campaignId];
                CampaignToken(campaignToken).mint(_user, likeReward);
                
                // 更新已花费预算
                campaignInfos[campaignId].spentBudget += likeReward;
            }
        }
    }
    
    // 检查campaign是否有效
    function _isCampaignValid(uint _campaignId, uint _rewardAmount) internal view returns (bool) {
        if (_campaignId >= nextCampaignId || campaigns[_campaignId] == address(0)) {
            return false;
        }
        
        CampaignInfo memory info = campaignInfos[_campaignId];
        return info.isActive && 
               block.timestamp >= info.startTime &&
               block.timestamp <= info.endTime &&
               info.spentBudget + _rewardAmount <= info.budget;
    }
    
    // 设置奖励
    function _setRewards(uint _commentReward, uint _likeReward) internal {
        commentReward = _commentReward;
        likeReward = _likeReward;
    }
    
    // 获取campaign token地址
    function _getCampaignToken(uint _campaignId) internal view returns (address) {
        return campaigns[_campaignId];
    }
    
    // 检查话题是否有关联的campaign
    function _topicHasCampaign(uint _topicId) internal view returns (bool) {
        return topicCampaigns[_topicId].length > 0;
    }
    
    // 获取话题的所有campaign
    function _getTopicCampaigns(uint _topicId) internal view returns (uint[] memory) {
        return topicCampaigns[_topicId];
    }
    
    // 获取活跃的campaigns
    function _getActiveCampaigns(uint _topicId) internal view returns (uint[] memory) {
        uint[] memory allCampaigns = topicCampaigns[_topicId];
        uint[] memory activeCampaigns = new uint[](allCampaigns.length);
        uint activeCount = 0;
        
        for (uint i = 0; i < allCampaigns.length; i++) {
            if (_isCampaignValid(allCampaigns[i], 0)) {
                activeCampaigns[activeCount] = allCampaigns[i];
                activeCount++;
            }
        }
        
        // 创建正确大小的数组
        uint[] memory result = new uint[](activeCount);
        for (uint i = 0; i < activeCount; i++) {
            result[i] = activeCampaigns[i];
        }
        
        return result;
    }
    
    // 获取campaign详细信息
    function _getCampaignInfo(uint _campaignId) internal view returns (CampaignInfo memory) {
        return campaignInfos[_campaignId];
    }
    
    // 手动结束campaign
    function _endCampaign(uint _campaignId) internal {
        require(_campaignId < nextCampaignId, "Campaign does not exist");
        campaignInfos[_campaignId].isActive = false;
    }
}
