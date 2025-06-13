// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {CampaignFactory} from "../token/CampaignFactory.sol";
import {CampaignToken} from "../token/Campaign.sol";
import {TopicBaseManager} from "./TopicBaseManager.sol";

// TopicManager是在TopicBaseManager的基础上，添加了话题管理功能
contract TopicManager is TopicBaseManager {
    CampaignFactory public campaignFactory;

    // 活动信息管理 - 一对多关系
    uint public nextCampaignId;
    uint public constant MAX_CAMPAIGNS_PER_TOPIC = 3; // 每个topic最多3个campaign
    
    mapping(uint => address) public campaigns; // campaignId => tokenAddress
    mapping(uint => uint[]) public topicCampaigns; // topicId => campaignId[] (一对多)
    
    // Campaign状态管理
    struct CampaignInfo {
        uint id;            // 活动id：主键，0开始，每次注册+1
        address sponsor;    // 活动赞助商
        uint topicId;       // 话题id：外键
        string name;        // 活动名称
        string description; // 活动描述
        bool isActive;      // 活动是否激活
        uint startTime;     // 活动开始时间
        uint endTime;       // 活动结束时间
        uint jackpot;       // 奖金池(美元计价)
        uint mintTokenAmount; // 活动期间mint的token数量(decimal 18)
        uint rewardUsdcPerMillionCPToken; // 每个CP token的得多少颗USDC
        uint rewardPtokenPerMillionCPToken; // 每个CP token的奖励
    }
    mapping(uint => CampaignInfo) public campaignInfos;
    
    // mint奖励配置
    uint public commentReward = 10 * 1e18;  // 评论奖励10个token
    uint public likeReward = 5 * 1e18;      // 点赞奖励5个token

    // 设置factory
    function _setCampaignFactory(address _factory) public {
        campaignFactory = CampaignFactory(_factory);
    }

    // 开始前，设置奖励
    function _setRewards(uint _commentReward, uint _likeReward) public {
        commentReward = _commentReward;
        likeReward = _likeReward;
    }

    // 增：注册活动
    function _registerCampaign(
        address _sponsor,
        uint _topicId,
        string memory _name,
        string memory _description
    ) public returns (bool, uint) {
        // 检查topic是否存在
        require(bytes(topics[_topicId].name).length > 0, "Topic not exist");

        // 检查该topic的campaign数量限制
        require(topicCampaigns[_topicId].length < MAX_CAMPAIGNS_PER_TOPIC, "Topic campaign limit reached");
        
        // 通过factory创建campaign token
        address campaignToken = campaignFactory.createCampaignToken(
            _name,
            string(abi.encodePacked(_name, "Token")),
            _topicId
        );
        
        // 设置campaign token地址 
        campaigns[nextCampaignId] = campaignToken;
        // 根据topicId，将campaignId添加到topicCampaigns中
        topicCampaigns[_topicId].push(nextCampaignId);
        
        // 设置campaign信息，注意此时活动还没有start，所以isActive为false
        campaignInfos[nextCampaignId] = CampaignInfo({
            id: nextCampaignId,                     // 活动id
            sponsor: _sponsor,                      // 活动赞助商
            topicId: _topicId,                      // 话题id
            name: _name,                            // 活动名称
            description: _description,              // 活动描述
            isActive: false,                        // 开始后转true，结束后再转false，活动是否激活
            startTime: 0,                           // 开始后记录：活动开始时间
            endTime: 0,                             // 开始后记录：活动结束时间
            jackpot: 0,                             // 开始后记录：活动奖金池
            mintTokenAmount: 0,                     // 结束后记录：活动期间mint的token数量
            rewardUsdcPerMillionCPToken: 0,         // 结束后记录：每百万CP token的得多少颗USDC
            rewardPtokenPerMillionCPToken: 0        // 结束后记录：每百万CP token的得多少颗项目方token
        });
        
        nextCampaignId++;

        // 返回创建成功和创建的campaignId
        return (true, nextCampaignId - 1);
    }

    // 改：活动开始
    function _startCampaign(uint _campaignId, uint _duration) public {
        require(_campaignId < nextCampaignId, "Campaign does not exist");
        CampaignToken c = CampaignToken(campaigns[_campaignId]);

        // token的信息更新到campaignInfo中
        c.start(_duration);
        // 更新四项信息
        campaignInfos[_campaignId].isActive = c.isActive();
        campaignInfos[_campaignId].startTime = c.startTime();
        campaignInfos[_campaignId].endTime = c.endTime();
        campaignInfos[_campaignId].jackpot = c.jackpotStart(); // 这里只是，但是会浮动

        // 检查token的信息是否更新到campaignInfo中，如果没更新，则说明start失败
        require(campaignInfos[_campaignId].isActive == true, "Campaign start isActive didn't change");
    }

    // 改：活动结束
    // chainlink自动检查是否已经到了时间，如果到了时间，则自动结束活动
    // 每1分钟检查一次 TODO
    function _endCampaign(uint _campaignId) public {
        // 检查活动是否不存在或已经结束
        require(_campaignId < nextCampaignId, "Campaign does not exist");
        require(campaignInfos[_campaignId].isActive, "Campaign is not active");

        // 调用token的finish方法
        CampaignToken c = CampaignToken(campaigns[_campaignId]);
        c.finish();
        campaignInfos[_campaignId].isActive = c.isActive();
        campaignInfos[_campaignId].mintTokenAmount = c.totalSupply();
        campaignInfos[_campaignId].rewardUsdcPerMillionCPToken = c.usdcPerMillionCPToken();
        campaignInfos[_campaignId].rewardPtokenPerMillionCPToken = c.ptokenPerMillionCPToken();

        // update更新一下奖池
        (campaignInfos[_campaignId].rewardUsdcPerMillionCPToken, 
        campaignInfos[_campaignId].rewardPtokenPerMillionCPToken, 
        campaignInfos[_campaignId].jackpot) = c.updateReward();

        // 检查token的信息是否更新到campaignInfo中，如果没更新，则说明finish失败
        require(campaignInfos[_campaignId].isActive == false, "Campaign finish isActive didn't change");
    }

    // 改：活动结束
    // chainlink检测到项目方token价格低于承诺的奖金价值，则自动结束活动
    // 每1分钟检查一次 TODO
    function _endCampaignByLowProjectTokenPrice(uint _campaignId) public {
        // 检查活动是否不存在或已经结束
        require(_campaignId < nextCampaignId, "Campaign does not exist");
        require(campaignInfos[_campaignId].isActive, "Campaign is not active");

        CampaignToken c = CampaignToken(campaigns[_campaignId]);
        c.finishByLowProjectTokenPrice();
        campaignInfos[_campaignId].isActive = c.isActive();
        campaignInfos[_campaignId].mintTokenAmount = c.totalSupply();
        campaignInfos[_campaignId].rewardUsdcPerMillionCPToken = c.usdcPerMillionCPToken();
        campaignInfos[_campaignId].rewardPtokenPerMillionCPToken = c.ptokenPerMillionCPToken();

        // update更新一下奖池
        c.updateReward();
        campaignInfos[_campaignId].jackpot = c.jackpotRealTime();

        // 检查token的信息是否更新到campaignInfo中，如果没更新，则说明finish失败
        require(campaignInfos[_campaignId].isActive == false, "Campaign finish isActive didn't change");
    }

    
    // 用户发起评论
    function _commentOnTopicIdMint(uint _topicId, address _user) public {
        uint[] memory campaignIds = topicCampaigns[_topicId];
        
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            if (campaignInfos[campaignId].isActive) {
                address campaignToken = campaigns[campaignId];
                CampaignToken(campaignToken).mint(_user, commentReward);
            }
        }
    }
    
    // 用户点赞
    function _likeCommentMint(uint _topicId, address _user) public {
        uint[] memory campaignIds = topicCampaigns[_topicId];
        
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            
            if (campaignInfos[campaignId].isActive) {
                address campaignToken = campaigns[campaignId];
                CampaignToken(campaignToken).mint(_user, likeReward);
            }
        }
    }
    
    // 获取Campaign信息
    function _getCampaignInfo(uint _campaignId) public view returns (CampaignInfo memory) {
        return campaignInfos[_campaignId];
    }
    
    // 获取Topic的Campaign列表
    function _getTopicCampaigns(uint _topicId) public view returns (uint[] memory) {
        return topicCampaigns[_topicId];
    }
}
