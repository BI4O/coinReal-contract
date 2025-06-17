// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TopicManager} from "./TopicManager.sol";
import {UserManager} from "./UserManager.sol";
import {CampaignToken} from "../token/Campaign.sol";

contract LinkArray {
    // 每个链表的大小
    mapping(address => mapping(uint => uint)) public listSize;
    
    // 链表头常量
    uint constant FIRST = 1;
    
    // 下一个元素指针 [owner][listType][currentId] => nextId
    mapping(address => mapping(uint => mapping(uint => uint))) private _next;
    
    // 链表头指针 [owner][listType] => firstId
    mapping(address => mapping(uint => uint)) public head;
    
    // 元素时间戳 [owner][listType][id] => timestamp
    mapping(address => mapping(uint => mapping(uint => uint))) public timestamps;
    
    // 链表类型常量
    uint public constant COMMENT_LIST = 1;
    uint public constant LIKE_LIST = 2;
    
    constructor() {
        // 无需初始化
    }
    
    // 添加元素到链表头部
    function addItem(address owner, uint listType, uint id, uint timestamp) public {
        // 确保ID不存在于链表中
        require(_next[owner][listType][id] == 0, "ID already exists");
        
        // 添加到链表头
        if (head[owner][listType] == 0) {
            // 首个元素
            head[owner][listType] = id;
            _next[owner][listType][id] = 0;
        } else {
            // 添加到头部
            _next[owner][listType][id] = head[owner][listType];
            head[owner][listType] = id;
        }
        
        // 记录时间戳
        timestamps[owner][listType][id] = timestamp;
        
        // 增加链表大小
        listSize[owner][listType]++;
    }
    
    // 从链表中移除元素
    function removeItem(address owner, uint listType, uint id, uint prevId) public {
        require(_next[owner][listType][id] != 0, "ID does not exist");
        
        if (prevId == 0) {
            // 如果是头部元素
            require(head[owner][listType] == id, "Invalid previous ID");
            head[owner][listType] = _next[owner][listType][id];
        } else {
            // 确认前一个元素正确指向当前元素
            require(_next[owner][listType][prevId] == id, "Invalid previous ID");
            // 更新前一个元素的指针
            _next[owner][listType][prevId] = _next[owner][listType][id];
        }
        
        // 清除当前元素
        _next[owner][listType][id] = 0;
        timestamps[owner][listType][id] = 0;
        
        // 减少链表大小
        listSize[owner][listType]--;
    }
    
    // 获取链表中的前n个元素
    function getItems(address owner, uint listType, uint n) public view returns (uint[] memory) {
        uint size = listSize[owner][listType];
        uint count = n < size ? n : size;
        
        uint[] memory items = new uint[](count);
        
        uint current = head[owner][listType];
        for (uint i = 0; i < count && current != 0; i++) {
            items[i] = current;
            current = _next[owner][listType][current];
        }
        
        return items;
    }
    
    // 检查元素是否存在
    function contains(address owner, uint listType, uint id) public view returns (bool) {
        return _next[owner][listType][id] != 0 || head[owner][listType] == id;
    }
    
    // 获取元素的下一个元素
    function getNext(address owner, uint listType, uint id) public view returns (uint) {
        return _next[owner][listType][id];
    }
}

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
    
    // 链表类型常量
    uint public constant COMMENT_LIST = 1;
    uint public constant LIKE_LIST = 2;

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

    // 记录用户所有的评论
    mapping(address => mapping(uint => uint)) public userComments;

    // 初始化LinkArray实例
    LinkArray private linkArray;

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
        linkArray = new LinkArray();
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
        
        // 更新用户评论链表
        linkArray.addItem(_user, COMMENT_LIST, nextCommentId, block.timestamp);

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
        
        // 更新用户点赞链表
        linkArray.addItem(_user, LIKE_LIST, nextLikeId, block.timestamp);

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

    // 查：给定用户id，查询用户评最近n个评论的id，
    function getRecentCommentsByUserAddress(address _userAddress, uint _n) public view returns (uint[] memory) {
        return linkArray.getItems(_userAddress, COMMENT_LIST, _n);
    }

    // 查：给定用户id，查询用户评最近n个like的id，
    function getRecentLikesByUserAddress(address _userAddress, uint _n) public view returns (uint[] memory) {
        return linkArray.getItems(_userAddress, LIKE_LIST, _n);
    }

    // 查：给定n，查最多like的n个评论
    function getMostLikedComments(uint _n) public view returns (uint[] memory) {
        if (nextCommentId == 0 || _n == 0) {
            return new uint[](0);
        }
        
        uint actualN = _n > nextCommentId ? nextCommentId : _n;
        uint[] memory result = new uint[](actualN);
        uint[] memory likeCounts = new uint[](actualN);
        
        // 初始化结果数组
        for (uint i = 0; i < actualN; i++) {
            result[i] = type(uint).max; // 使用最大值作为未初始化标记
            likeCounts[i] = 0;
        }
        
        // 遍历所有评论，找到点赞数最多的n个
        for (uint commentId = 0; commentId < nextCommentId; commentId++) {
            // 跳过已删除的评论
            if (comments[commentId].isDelete) continue;
            
            uint currentLikes = comments[commentId].likeCount;
            
            // 找到应该插入的位置
            for (uint j = 0; j < actualN; j++) {
                if (result[j] == type(uint).max || currentLikes > likeCounts[j]) {
                    // 向后移动元素
                    for (uint k = actualN - 1; k > j; k--) {
                        result[k] = result[k-1];
                        likeCounts[k] = likeCounts[k-1];
                    }
                    // 插入新元素
                    result[j] = commentId;
                    likeCounts[j] = currentLikes;
                    break;
                }
            }
        }
        
        // 移除未初始化的元素
        uint validCount = 0;
        for (uint i = 0; i < actualN; i++) {
            if (result[i] != type(uint).max) {
                validCount++;
            }
        }
        
        uint[] memory finalResult = new uint[](validCount);
        for (uint i = 0; i < validCount; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }

    // 查：给定n，查最小like的n个评论
    function getLeastLikedComments(uint _n) public view returns (uint[] memory) {
        if (nextCommentId == 0 || _n == 0) {
            return new uint[](0);
        }
        
        uint actualN = _n > nextCommentId ? nextCommentId : _n;
        uint[] memory result = new uint[](actualN);
        uint[] memory likeCounts = new uint[](actualN);
        
        // 初始化结果数组
        for (uint i = 0; i < actualN; i++) {
            result[i] = type(uint).max; // 使用最大值作为未初始化标记
            likeCounts[i] = type(uint).max; // 使用最大值作为初始比较值
        }
        
        // 遍历所有评论，找到点赞数最少的n个
        for (uint commentId = 0; commentId < nextCommentId; commentId++) {
            // 跳过已删除的评论
            if (comments[commentId].isDelete) continue;
            
            uint currentLikes = comments[commentId].likeCount;
            
            // 找到应该插入的位置
            for (uint j = 0; j < actualN; j++) {
                if (result[j] == type(uint).max || currentLikes < likeCounts[j]) {
                    // 向后移动元素
                    for (uint k = actualN - 1; k > j; k--) {
                        result[k] = result[k-1];
                        likeCounts[k] = likeCounts[k-1];
                    }
                    // 插入新元素
                    result[j] = commentId;
                    likeCounts[j] = currentLikes;
                    break;
                }
            }
        }
        
        // 移除未初始化的元素
        uint validCount = 0;
        for (uint i = 0; i < actualN; i++) {
            if (result[i] != type(uint).max) {
                validCount++;
            }
        }
        
        uint[] memory finalResult = new uint[](validCount);
        for (uint i = 0; i < validCount; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }

    // 查：分页获取最多点赞的评论 (startIndex: 起始索引, length: 获取数量)
    function getMostLikedCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        if (nextCommentId == 0 || length == 0) {
            return new uint[](0);
        }
        
        // 创建所有有效评论的数组
        uint[] memory validComments = new uint[](nextCommentId);
        uint[] memory likeCounts = new uint[](nextCommentId);
        uint validCount = 0;
        
        // 收集所有未删除的评论
        for (uint commentId = 0; commentId < nextCommentId; commentId++) {
            if (!comments[commentId].isDelete) {
                validComments[validCount] = commentId;
                likeCounts[validCount] = comments[commentId].likeCount;
                validCount++;
            }
        }
        
        // 如果没有有效评论
        if (validCount == 0) {
            return new uint[](0);
        }
        
        // 使用冒泡排序按点赞数降序排列
        for (uint i = 0; i < validCount - 1; i++) {
            for (uint j = 0; j < validCount - i - 1; j++) {
                if (likeCounts[j] < likeCounts[j + 1]) {
                    // 交换点赞数
                    uint tempLikes = likeCounts[j];
                    likeCounts[j] = likeCounts[j + 1];
                    likeCounts[j + 1] = tempLikes;
                    
                    // 交换评论ID
                    uint tempComment = validComments[j];
                    validComments[j] = validComments[j + 1];
                    validComments[j + 1] = tempComment;
                }
            }
        }
        
        // 计算分页结果
        if (startIndex >= validCount) {
            return new uint[](0);
        }
        
        uint endIndex = startIndex + length;
        if (endIndex > validCount) {
            endIndex = validCount;
        }
        
        uint resultLength = endIndex - startIndex;
        uint[] memory result = new uint[](resultLength);
        
        for (uint i = 0; i < resultLength; i++) {
            result[i] = validComments[startIndex + i];
        }
        
        return result;
    }

    // 查：分页获取最少点赞的评论 (startIndex: 起始索引, length: 获取数量)
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        if (nextCommentId == 0 || length == 0) {
            return new uint[](0);
        }
        
        // 创建所有有效评论的数组
        uint[] memory validComments = new uint[](nextCommentId);
        uint[] memory likeCounts = new uint[](nextCommentId);
        uint validCount = 0;
        
        // 收集所有未删除的评论
        for (uint commentId = 0; commentId < nextCommentId; commentId++) {
            if (!comments[commentId].isDelete) {
                validComments[validCount] = commentId;
                likeCounts[validCount] = comments[commentId].likeCount;
                validCount++;
            }
        }
        
        // 如果没有有效评论
        if (validCount == 0) {
            return new uint[](0);
        }
        
        // 使用冒泡排序按点赞数升序排列
        for (uint i = 0; i < validCount - 1; i++) {
            for (uint j = 0; j < validCount - i - 1; j++) {
                if (likeCounts[j] > likeCounts[j + 1]) {
                    // 交换点赞数
                    uint tempLikes = likeCounts[j];
                    likeCounts[j] = likeCounts[j + 1];
                    likeCounts[j + 1] = tempLikes;
                    
                    // 交换评论ID
                    uint tempComment = validComments[j];
                    validComments[j] = validComments[j + 1];
                    validComments[j + 1] = tempComment;
                }
            }
        }
        
        // 计算分页结果
        if (startIndex >= validCount) {
            return new uint[](0);
        }
        
        uint endIndex = startIndex + length;
        if (endIndex > validCount) {
            endIndex = validCount;
        }
        
        uint resultLength = endIndex - startIndex;
        uint[] memory result = new uint[](resultLength);
        
        for (uint i = 0; i < resultLength; i++) {
            result[i] = validComments[startIndex + i];
        }
        
        return result;
    }

    // 查：获取有效评论总数（用于分页计算）
    function getValidCommentsCount() public view returns (uint) {
        uint count = 0;
        for (uint commentId = 0; commentId < nextCommentId; commentId++) {
            if (!comments[commentId].isDelete) {
                count++;
            }
        }
        return count;
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

        return true;
    }
} 