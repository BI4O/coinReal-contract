// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TopicManager} from "./TopicManager.sol";
import {UserManager} from "./UserManager.sol";
import {CampaignToken} from "../token/Campaign.sol";

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

        // 更新topic的commentCount
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

        return true;
    }
} 