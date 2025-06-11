// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserManager} from "./core/UserManager.sol";
import {TopicManager} from "./core/TopicManager.sol";
import {ActionManager} from "./core/ActionManager.sol";
import {CampaignManager} from "./core/CampaignManager.sol";

/*
APP管理
1. Topic
2. User  
3. Action (评论、点赞等用户行为)
4. Campaign (激励机制)
*/ 

contract App is UserManager, TopicManager, ActionManager, CampaignManager {
    // 管理员
    address public admin;   
  
    // 合约创建
    constructor() {admin = msg.sender;}
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    // 本项目金库
    receive() external payable {}
    function balanceOfApp() public view returns (uint) {
        return address(this).balance;
    }
    function withdraw() public onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    // 用户注册
    function registerUser(
        string memory _name, 
        string memory _bio, 
        string memory _email
    ) public {
        _registerUser(_name, _bio, _email);
    }
    // 用户查询
    function getUser(address _user) public view returns (User memory) {
        return _getUser(_user);
    }

    // 话题注册
    function registerTopic(
        string memory _name, 
        string memory _description, 
        string memory _tokenAddress
    ) public onlyAdmin {
        _registerTopic(_name, _description, _tokenAddress);
    }
    // 话题查询
    function getTopic(uint _topicId) public view returns (Topic memory) {
        return _getTopic(_topicId);
    }

    // 活动注册
    function registerCampaign(
        address _sponsor,
        string memory _name,
        string memory _description,
        uint _topicId,
        uint _budget,
        uint _duration
    ) public onlyAdmin {
        _registerCampaign(_sponsor, _name, _description, _topicId, _budget, _duration);
    }
    
    // 用户评论话题
    function commentOnTopic(uint _topicId, string memory _content) public {
        // 1. ActionManager记录用户行为
        _addComment(_topicId, msg.sender, _content);
        
        // 2. CampaignManager处理token激励（如果该topic有campaign）
        _handleCommentReward(_topicId, msg.sender);
    }
    
    // 用户给评论点赞
    function likeComment(uint _commentId) public {
        // 1. ActionManager记录点赞行为
        _likeComment(_commentId, msg.sender);
        
        // 2. CampaignManager处理token激励
        uint topicId = _getCommentTopicId(_commentId);
        _handleLikeReward(topicId, msg.sender);
    }
    
    // 初始化campaign合约（部署后调用一次）
    function initializeCampaignContracts(address _factory) public onlyAdmin {
        _setCampaignFactory(_factory);
    }
    
    // 设置奖励配置
    function setRewards(uint _commentReward, uint _likeReward) public onlyAdmin {
        _setRewards(_commentReward, _likeReward);
    }
    
    // 获取用户是否已评论话题
    function hasUserCommented(uint _topicId, address _user) public view returns (bool) {
        return _hasUserCommented(_topicId, _user);
    }
    
    // 获取用户是否给评论点赞
    function hasUserLikedComment(uint _commentId, address _user) public view returns (bool) {
        return _hasUserLikedComment(_commentId, _user);
    }
    
    // 检查话题是否有关联的campaign
    function topicHasCampaign(uint _topicId) public view returns (bool) {
        return _topicHasCampaign(_topicId);
    }
    
    // 获取campaign token地址
    function getCampaignToken(uint _campaignId) public view returns (address) {
        return _getCampaignToken(_campaignId);
    }
    
    // 获取话题的评论列表
    function getTopicComments(uint _topicId) public view returns (uint[] memory) {
        return _getTopicComments(_topicId);
    }
    
    // 获取评论详情
    function getComment(uint _commentId) public view returns (Comment memory) {
        return _getComment(_commentId);
    }
    
    // 获取话题的所有campaigns
    function getTopicCampaigns(uint _topicId) public view returns (uint[] memory) {
        return _getTopicCampaigns(_topicId);
    }
    
    // 获取话题的活跃campaigns
    function getActiveCampaigns(uint _topicId) public view returns (uint[] memory) {
        return _getActiveCampaigns(_topicId);
    }
    
    // 获取campaign详细信息
    function getCampaignInfo(uint _campaignId) public view returns (CampaignInfo memory) {
        return _getCampaignInfo(_campaignId);
    }
    
    // 结束campaign
    function endCampaign(uint _campaignId) public onlyAdmin {
        _endCampaign(_campaignId);
    }
}