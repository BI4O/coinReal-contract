// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UserManager.sol";
import "./TopicManager.sol";
import "./ActionManager.sol";
import {USDC} from "../token/USDC.sol";
import {ProjectToken} from "../token/ProjectToken.sol";
import {CampaignFactory} from "../token/CampaignFactory.sol";

contract App {
    // 使用组合模式而不是继承
    UserManager public userManager;
    TopicManager public topicManager;  // TopicManager已经继承了TopicItem
    ActionManager public actionManager;
    USDC public usdc;
    ProjectToken public projectToken;
    CampaignFactory public campaignFactory;
    
    // 权限控制
    address public owner;
    
    modifier onlyAdmin() {
        require(msg.sender == owner, "Only admin can call this function");
        _;
    }
    
    modifier onlyRegisteredUser() {
        require(userManager.getUserInfo(msg.sender).registered, "User not registered");
        _;
    }
    
    constructor(
        address _usdcAddr,
        address _userManager,
        address _topicManager,
        address _actionManager
    ) {
        owner = msg.sender;
        usdc = USDC(_usdcAddr);
        userManager = UserManager(_userManager);
        topicManager = TopicManager(_topicManager);
        actionManager = ActionManager(_actionManager);
    }
    
    // 注册用户
    function registerUser(string memory _name, string memory _bio, string memory _email) public {
        userManager.registerUser(msg.sender, _name, _bio, _email);
    }

    // 注册话题
    function registerTopic(
        string memory _name, 
        string memory _description, 
        string memory _tokenAddress, 
        uint _tokenPrice
    ) public onlyAdmin {
        topicManager.registerTopic(_name, _description, _tokenAddress, _tokenPrice);
    }

    // 注册活动
    // 管理员才可以上新栏目
    function registerCampaign(
        address _sponsor, 
        uint _topicId, 
        string memory _name, 
        string memory _description, 
        address _projectTokenAddr
    ) public {
        topicManager.registerCampaign(_sponsor, _topicId, _name, _description, _projectTokenAddr);
    }

    // 活动注资
    function fundCampaignWithUSDC(uint _campaignId, uint _amount) public {
        // 获取CampaignToken地址
        address campaignTokenAddr = topicManager.getCampaignToken(_campaignId);
        // 直接从调用者转账USDC到CampaignToken合约
        usdc.transferFrom(msg.sender, campaignTokenAddr, _amount);
    }

    // 活动注资
    function fundCampaignWithProjectToken(uint _campaignId, uint _amount) public {
        // 获取CampaignToken地址和项目代币地址
        address campaignTokenAddr = topicManager.getCampaignToken(_campaignId);
        ProjectToken ptoken = ProjectToken(topicManager.getCampaignInfo(_campaignId).projectTokenAddr);
        // 直接从调用者转账项目代币到CampaignToken合约
        ptoken.transferFrom(msg.sender, campaignTokenAddr, _amount);
    }

    // 活动开始
    function startCampaign(uint _campaignId, uint _endTime) public {
        topicManager.startCampaign(_campaignId, _endTime);
    }

    // 活动结束
    function endCampaign(uint _campaignId) public {
        topicManager.endCampaign(_campaignId);
    }

    // 点赞
    function like(uint _topicId, uint _commentId) public onlyRegisteredUser {
        actionManager.addLike(_topicId, _commentId, msg.sender);
    }

    // 评论
    function comment(uint _topicId, string memory _content) public onlyRegisteredUser {
        actionManager.addComment(_topicId, msg.sender, _content);
    }

    // 查询功能

    // 获取用户最近的n个评论ID
    function getUserRecentComments(address _userAddress, uint _n) public view returns (uint[] memory) {
        return actionManager.getRecentCommentsByUserAddress(_userAddress, _n);
    }

    // 获取用户最近的n个点赞ID
    function getUserRecentLikes(address _userAddress, uint _n) public view returns (uint[] memory) {
        return actionManager.getRecentLikesByUserAddress(_userAddress, _n);
    }

    // 获取点赞数最多的n个评论ID
    function getMostLikedComments(uint _n) public view returns (uint[] memory) {
        return actionManager.getMostLikedComments(_n);
    }

    // 获取点赞数最少的n个评论ID
    function getLeastLikedComments(uint _n) public view returns (uint[] memory) {
        return actionManager.getLeastLikedComments(_n);
    }

    // 分页获取点赞数最多的评论ID
    function getMostLikedCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return actionManager.getMostLikedCommentsPaginated(startIndex, length);
    }

    // 分页获取点赞数最少的评论ID
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return actionManager.getLeastLikedCommentsPaginated(startIndex, length);
    }

    // 获取有效评论总数
    function getValidCommentsCount() public view returns (uint) {
        return actionManager.getValidCommentsCount();
    }

    // 根据评论ID获取评论详情
    function getComment(uint _commentId) public view returns (ActionManager.Comment memory) {
        return actionManager.getComment(_commentId);
    }

    // 根据点赞ID获取点赞详情
    function getLike(uint _likeId) public view returns (ActionManager.Like memory) {
        return actionManager.getLike(_likeId);
    }

    // 获取评论的点赞数
    function getCommentLikeCount(uint _commentId) public view returns (uint) {
        return actionManager.getLikeCount(_commentId);
    }

    // 获取评论的标签
    function getCommentTags(uint _commentId) public view returns (string[] memory) {
        return actionManager.getCommentTags(_commentId);
    }

    // 管理功能

    // 为评论添加标签（只有管理员可以）
    function addCommentTags(uint _commentId, string[] memory _tags) public onlyAdmin {
        actionManager.addTags(_commentId, _tags);
    }

    // 删除评论（只有评论作者可以）
    function deleteComment(uint _commentId) public onlyRegisteredUser {
        actionManager.deleteCommentByUser(_commentId, msg.sender);
    }
}