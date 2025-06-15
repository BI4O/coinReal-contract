// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {CampaignFactory} from "../token/CampaignFactory.sol";
import {CampaignToken} from "../token/Campaign.sol";
import {TopicItem} from "./TopicItem.sol";
import {USDC} from "../token/USDC.sol";

// TopicManager是在TopicItem的基础上，添加了话题管理功能
contract TopicManager is TopicItem {

    // 权限控制
    address public owner;

    // 接受的USDC地址
    USDC public usdc;

    CampaignFactory public campaignFactory; // 活动工厂

    // 活动信息管理 - 一对多关系
    uint public nextCampaignId;
    uint public constant MAX_CAMPAIGNS_PER_TOPIC = 3; // 每个topic最多3个campaign
    
    mapping(uint => address) public campaigns; // campaignId => tokenAddress
    mapping(uint => uint[]) public topicCampaigns; // topicId => campaignId[] (一对多)
    
    // Campaign状态管理
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
    mapping(uint => CampaignInfo) public campaignInfos;
    

    // 构造函数，接受的USDC地址
    constructor(address _usdcAddr) {
        owner = msg.sender;
        usdc = USDC(_usdcAddr);
        campaignFactory = new CampaignFactory(_usdcAddr);
    }

    function setOwner(address _owner) public {
        require(msg.sender == owner, "Only owner can call this function");
        owner = _owner;
    }

    // 增：注册活动
    function registerCampaign(
        address _sponsor,
        uint _topicId,
        string memory _name,
        string memory _description,
        address _projectTokenAddr
    ) public returns (bool, uint) {
        // 检查topic是否存在
        require(bytes(topics[_topicId].name).length > 0, "Topic not exist");

        // 检查该topic的campaign数量限制
        require(topicCampaigns[_topicId].length < MAX_CAMPAIGNS_PER_TOPIC, "Topic campaign limit reached");
        
        // 通过factory创建campaign token
        address campaignToken = campaignFactory.createCampaignToken(
            _name,
            string(abi.encodePacked(_name, "Token")),
            _topicId,
            _projectTokenAddr
        );
        
        // 设置campaign token地址 
        campaigns[nextCampaignId] = campaignToken;
        // 根据topicId，将campaignId添加到topicCampaigns中
        topicCampaigns[_topicId].push(nextCampaignId);
        
        // 设置campaign信息，注意此时活动还没有start，所以isActive为false
        campaignInfos[nextCampaignId] = CampaignInfo({
            // 创建参数
            id: nextCampaignId,                     // 活动id
            sponsor: _sponsor,                      // 活动赞助商
            topicId: _topicId,                      // 话题id
            name: _name,                            // 活动名称
            description: _description,              // 活动描述
            projectTokenAddr: _projectTokenAddr,    // 项目代币地址

            // 非创建参数
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

    // 活动开始前注资USDC
    function fundCampaignWithUSDC(uint _campaignId, uint _amount) public {
        CampaignToken c = CampaignToken(campaigns[_campaignId]);
        usdc.transferFrom(msg.sender, address(c), _amount);
    }

    // 活动开始前注资项目代币
    function fundCampaignWithProjectToken(uint _campaignId, uint _amount) public {
        CampaignToken c = CampaignToken(campaigns[_campaignId]);
        c.projectToken().transferFrom(msg.sender, address(c), _amount);
    }   

    // 查询还差多少注资
    function campaignNeedFundInUSD(uint _campaignId) public view returns (int) {
        CampaignToken c = CampaignToken(campaigns[_campaignId]);
        uint currentFunded = c.getFundedUSDC() + c.getFundedProjectToken() * c.projectToken().getPrice();
        // 如果是纯USDC注资，则直接返回差值
        if (c.getFundedProjectToken() == 0) {
            if (currentFunded >= c.minJackpot()) {
                return 0; // 已经满足最低要求
            } else {
                return int(c.minJackpot() - currentFunded);
            }
        } else {
            // 如果是掺杂了项目代币，则需要计算总奖金价值，如果小于minJackpot，则触发自动结束
            uint requiredAmount = c.minJackpot() * 15 / 10;
            if (currentFunded >= requiredAmount) {
                return 0; // 已经满足要求
            } else {
                return int(requiredAmount - currentFunded);
            }
        }
    }

    // 辅助函数：检查活动是否可以开始
    function checkCampaignCanStart(uint _campaignId) public view returns (bool) {
        return campaignNeedFundInUSD(_campaignId) <= 0;
    }

    // 改：活动开始
    function startCampaign(uint _campaignId, uint _endTime) public {
        require(_campaignId < nextCampaignId, "Campaign does not exist");
        require(checkCampaignCanStart(_campaignId) == true, "Campaign funding is not enough");
        CampaignToken c = CampaignToken(campaigns[_campaignId]);

        // token的信息更新到campaignInfo中
        c.start(_endTime);
        // 更新四项信息
        campaignInfos[_campaignId].isActive = c.isActive();
        campaignInfos[_campaignId].startTime = c.startTime();
        campaignInfos[_campaignId].endTime = c.endTime();
        campaignInfos[_campaignId].jackpot = c.jackpotStart(); // 这里只是初始值，但是会浮动

        // 检查token的信息是否更新到campaignInfo中，如果没更新，则说明start失败
        require(campaignInfos[_campaignId].isActive == true, "Campaign start isActive didn't change");
    }

    // 改：活动结束
    function endCampaign(uint _campaignId) public {
        require(_campaignId < nextCampaignId, "Campaign does not exist");
        require(campaignInfos[_campaignId].isActive, "Campaign is not active");

        CampaignToken c = CampaignToken(campaigns[_campaignId]);

        // 尝试调用finish方法，如果失败，则尝试调用finishByLowTotalJackpot方法
        bool isFinished = c.finish();
        if (!isFinished) {
            isFinished = c.finishByLowTotalJackpot();
        }
        require(isFinished, "Campaign finish failed");

        // 更新结构体信息
        campaignInfos[_campaignId].isActive = c.isActive();
        campaignInfos[_campaignId].mintTokenAmount = c.totalSupply();
        campaignInfos[_campaignId].rewardUsdcPerMillionCPToken = c.usdcPerMillionCPToken();
        campaignInfos[_campaignId].rewardPtokenPerMillionCPToken = c.ptokenPerMillionCPToken();
        campaignInfos[_campaignId].jackpot = c.jackpotRealTime();
    }

    // 删除活动
    function deleteTopic(uint _topicId) public {
        require(_topicId < nextTopicId, "Topic does not exist");

        // 删除topic
        deleteTopicToken(_topicId);

        // 找到这些关联的campaignId
        uint[] memory campaignIds = topicCampaigns[_topicId];
        for (uint i = 0; i < campaignIds.length; i++) {
            // 删除campaign
            delete campaigns[campaignIds[i]];
            delete campaignInfos[campaignIds[i]];
        }
        // 删除topicCampaigns中的campaignId
        topicCampaigns[_topicId] = new uint[](0);       
    }
    
    // 获取Campaign信息
    function getCampaignInfo(uint _campaignId) public view returns (CampaignInfo memory) {
        return campaignInfos[_campaignId];
    }

    // 获取Campaign token地址
    function getCampaignToken(uint _campaignId) public view returns (address) {
        return campaigns[_campaignId];
    }
    
    // 获取Topic的Campaign列表
    function getTopicCampaigns(uint _topicId) public view returns (uint[] memory) {
        return topicCampaigns[_topicId];
    }
}
