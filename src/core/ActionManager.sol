// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TopicManager} from "./TopicManager.sol";
import {UserManager} from "./UserManager.sol";
import {CampaignToken} from "../token/Campaign.sol";
import {TimeSerLinkArray} from "../utils/TimeSerLinkArray.sol";
import {CountSerLinkArray} from "../utils/CountSerLinkArray.sol";

contract ActionManager {
    address public owner;

    // 用来校验topic是否存在
    TopicManager public topicManager;
    UserManager public userManager;

    uint public nextCommentId;
    uint public nextLikeId;

    // 活动奖励金额
    uint public commentRewardAmount;
    uint public commentRewardExtraAmount;
    uint public likeRewardAmount;

    // 评论
    struct Comment {
        uint id;
        address user;
        uint topicId;
        uint timestamp;

        // 特殊属性
        uint likeCount;
        bool isDelete;
        string content;
        string[] tags;
    }

    // 点赞
    struct Like {
        uint id;
        address user;
        uint topicId;   
        uint timestamp;

        // 特殊属性
        uint commentId;
        bool isCancel;
    }
    
    // id是主键
    mapping(uint => Comment) public comments;
    mapping(uint => Like) public likes;

    // 检验重复点赞 [commentId][user]
    mapping(uint => mapping(address => bool)) public hasLiked;
    // 检验某个评论对各个活动的Token的奖励的余额 [commentId][campaignId]
    mapping(uint => mapping(uint => uint)) public commentToTokenRewardBalances;

    // 链表实例
    TimeSerLinkArray public timeSerLinkArray;
    CountSerLinkArray public countSerLinkArray;

    // 构造函数
    constructor(
        address _topicManagerAddr, 
        address _userManagerAddr,
        uint _commentRewardAmount,
        uint _likeRewardAmount
    ) {
        nextCommentId = 0;
        nextLikeId = 0;
        owner = msg.sender;
        topicManager = TopicManager(_topicManagerAddr);
        userManager = UserManager(_userManagerAddr);
        commentRewardAmount = _commentRewardAmount;
        likeRewardAmount = _likeRewardAmount;
        commentRewardExtraAmount = _likeRewardAmount / 2; // 设置为点赞奖励的一半
        
        // 初始化链表
        timeSerLinkArray = new TimeSerLinkArray();
        countSerLinkArray = new CountSerLinkArray();
    }

    function setOwner(address _owner) public {
        require(msg.sender == owner, "Only owner can call this function");
        owner = _owner;
    }

    // 奖励：
    // 1. 评论奖励
    function commentRewardOrBurn(uint topicId, uint commentId, address user, bool isBurn) private {
        // 获取这个topic所有的活动
        uint[] memory campaignIds = topicManager.getTopicCampaigns(topicId);
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            address campaignToken = topicManager.getCampaignToken(campaignId);
            if (isBurn) {
                CampaignToken(campaignToken).burn(user, commentRewardAmount);
                // 把这个评论别人点赞赋予的额外奖励也烧掉
                uint extraReward = comments[commentId].likeCount * commentRewardExtraAmount;
                CampaignToken(campaignToken).burn(user, extraReward);
                commentToTokenRewardBalances[commentId][campaignId] -= (commentRewardAmount + extraReward);
                // 更新comment的likeCount
                comments[commentId].likeCount = 0;
            } else {
                CampaignToken(campaignToken).mint(user, commentRewardAmount);
                commentToTokenRewardBalances[commentId][campaignId] += commentRewardAmount;
            }
        }
    }

    // 2. 点赞奖励
    function likeReward(uint topicId, uint likeId, address user) private {
        // 获取这个topic所有的活动
        uint[] memory campaignIds = topicManager.getTopicCampaigns(topicId);
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            address campaignToken = topicManager.getCampaignToken(campaignId);
            CampaignToken(campaignToken).mint(user, likeRewardAmount);
            // 额外奖励给到评论者
            address commentUser = comments[likes[likeId].commentId].user;
            CampaignToken(campaignToken).mint(commentUser, commentRewardExtraAmount);
            commentToTokenRewardBalances[likes[likeId].commentId][campaignId] += commentRewardExtraAmount;
            // 更新comment的likeCount
            comments[likes[likeId].commentId].likeCount++;
        }
    }

    // 给评论增加tags
    function addTags(uint commentId, string[] memory tags) public {
        // 评论必须存在 - 修改检查逻辑
        require(commentId < nextCommentId, "Comment does not exist");
        // 评论必须未删除
        require(comments[commentId].isDelete != true, "Comment is already deleted");
        // 增加tags
        comments[commentId].tags = tags;
    }

    // 增：评论
    function addComment(
        uint _topicId, 
        address _user, 
        string memory _content
    ) public returns(bool,uint){
        // topic必须存在
        require(bytes(topicManager.getTopic(_topicId).name).length > 0, "Topic does not exist");
        // user必须存在
        require(userManager.getUserInfo(_user).registered, "User does not exist");

        // 创建评论
        comments[nextCommentId] = Comment({
            id: nextCommentId,
            topicId: _topicId,
            user: _user,
            content: _content,
            likeCount: 0,
            timestamp: block.timestamp,
            isDelete: false,
            tags: new string[](0)
        });

        // 奖励代币
        commentRewardOrBurn(_topicId, nextCommentId, _user, false);
        
        // 添加到时间序列链表（用户评论历史）
        timeSerLinkArray.addItem(_user, timeSerLinkArray.COMMENT_LIST(), nextCommentId, block.timestamp);
        
        // 添加到点赞数序列链表（全局排序）
        countSerLinkArray.addComment(nextCommentId);

        // 更新nextCommentId
        nextCommentId++;

        return (true, nextCommentId - 1);
    }

    // 增：点赞
    function addLike(
        uint _topicId, 
        uint _commentId,
        address _user
    ) public returns(bool,uint){
        // 校验用户是否已经注册
        require(userManager.getUserInfo(_user).registered, "User does not exist");

        // 校验topic是否存在
        require(bytes(topicManager.getTopic(_topicId).name).length > 0, "Topic does not exist");

        // comment必须存在
        require(comments[_commentId].isDelete != true, "Comment does not exist");

        // 防止重复点赞
        require(hasLiked[_commentId][_user] != true, "You have already liked this comment");

        // 创建点赞
        likes[nextLikeId] = Like({
            id: nextLikeId,
            topicId: _topicId,
            user: _user,
            commentId: _commentId,
            timestamp: block.timestamp,
            isCancel: false
        });

        // 更新hasLiked
        hasLiked[_commentId][_user] = true;

        // 更新comment的likeCount
        comments[_commentId].likeCount++;

        // 奖励代币
        likeReward(_topicId, nextLikeId, _user);
        
        // 添加到时间序列链表（用户点赞历史）
        timeSerLinkArray.addItem(_user, timeSerLinkArray.LIKE_LIST(), nextLikeId, block.timestamp);
        
        // 更新点赞数序列链表中评论的位置
        countSerLinkArray.updateLikeCount(_commentId, comments[_commentId].likeCount);

        // 更新nextLikeId
        nextLikeId++;

        return (true, nextLikeId - 1);
    }

    // 查：根据id获取评论
    function getComment(uint _commentId) public view returns (Comment memory) {
        return comments[_commentId];
    }

    // 查：根据id获取点赞
    function getLike(uint _likeId) public view returns (Like memory) {
        return likes[_likeId];
    }

    // 查：根据id获取点赞数量
    function getLikeCount(uint _commentId) public view returns (uint) {
        return comments[_commentId].likeCount;
    }

    // 查：根据id获取评论tags
    function getCommentTags(uint _commentId) public view returns (string[] memory) {
        return comments[_commentId].tags;
    }

    // 查：给定用户id，查询用户最近n个评论的id
    function getRecentCommentsByUserAddress(address _userAddress, uint _n) public view returns (uint[] memory) {
        return timeSerLinkArray.getRecentItems(_userAddress, timeSerLinkArray.COMMENT_LIST(), _n);
    }

    // 查：给定用户id，查询用户最近n个like的id
    function getRecentLikesByUserAddress(address _userAddress, uint _n) public view returns (uint[] memory) {
        return timeSerLinkArray.getRecentItems(_userAddress, timeSerLinkArray.LIKE_LIST(), _n);
    }

    // 查：给定n，查最多like的n个评论
    function getMostLikedComments(uint _n) public view returns (uint[] memory) {
        return countSerLinkArray.getMostLikedComments(_n);
    }

    // 查：给定n，查最少like的n个评论
    function getLeastLikedComments(uint _n) public view returns (uint[] memory) {
        return countSerLinkArray.getLeastLikedComments(_n);
    }

    // 查：分页获取最多点赞的评论 (startIndex: 起始索引, length: 获取数量)
    function getMostLikedCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return countSerLinkArray.getMostLikedCommentsPaginated(startIndex, length);
    }

    // 查：分页获取最少点赞的评论 (startIndex: 起始索引, length: 获取数量)
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return countSerLinkArray.getLeastLikedCommentsPaginated(startIndex, length);
    }

    // 查：分页取最近n条评论
    function getRecentCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.COMMENT_LIST(), startIndex, length);
    }

    // 查：分页取最近n条like
    function getRecentLikesPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.LIKE_LIST(), startIndex, length);
    }

    // 查：获取有效评论总数（用于分页计算）
    function getValidCommentsCount() public view returns (uint) {
        return countSerLinkArray.getValidCommentsCount();
    }

    // 查：获取全局评论总数（用于时间序列分页计算）
    function getGlobalCommentsCount() public view returns (uint) {
        return timeSerLinkArray.getGlobalListSize(timeSerLinkArray.COMMENT_LIST());
    }

    // 查：获取全局点赞总数（用于时间序列分页计算）
    function getGlobalLikesCount() public view returns (uint) {
        return timeSerLinkArray.getGlobalListSize(timeSerLinkArray.LIKE_LIST());
    }

    // 删：删除评论
    function deleteComment(uint _commentId) public returns(bool) {
        // 只有评论作者可以删除
        require(comments[_commentId].user == msg.sender, "You are not the author of this comment");
        // 评论必须未删除
        require(comments[_commentId].isDelete != true, "Comment is already deleted");  

        // 取消之前评论获得的代币
        commentRewardOrBurn(
            comments[_commentId].topicId, 
            _commentId, 
            comments[_commentId].user,
            true
        );

        // 删除评论
        comments[_commentId].isDelete = true;
        
        // 在点赞数序列链表中标记为已删除
        countSerLinkArray.deleteComment(_commentId);

        return true;
    }

    // 删：删除评论（由指定用户调用，用于App合约）
    function deleteCommentByUser(uint _commentId, address _user) public returns(bool) {
        // 只有评论作者可以删除
        require(comments[_commentId].user == _user, "You are not the author of this comment");
        // 评论必须未删除
        require(comments[_commentId].isDelete != true, "Comment is already deleted");  

        // 取消之前评论获得的代币
        commentRewardOrBurn(
            comments[_commentId].topicId, 
            _commentId, 
            comments[_commentId].user,
            true
        );

        // 删除评论
        comments[_commentId].isDelete = true;
        
        // 在点赞数序列链表中标记为已删除
        countSerLinkArray.deleteComment(_commentId);

        return true;
    }
} 