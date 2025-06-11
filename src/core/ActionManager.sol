// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ActionManager {
    // 评论系统
    uint public nextCommentId;
    struct Comment {
        uint id;                    // 评论ID
        uint topicId;              // 话题ID
        address author;            // 评论作者
        string content;            // 评论内容
        uint timestamp;            // 评论时间
        uint likeCount;            // 点赞数
    }
    
    mapping(uint => Comment) public comments; // commentId => Comment
    mapping(uint => uint[]) public topicComments; // topicId => commentId[]
    
    // 用户行为记录
    mapping(uint => mapping(address => bool)) public hasCommented; // topicId => user => bool
    mapping(uint => mapping(address => bool)) public hasLikedComment; // commentId => user => bool

    // 添加评论
    function _addComment(uint _topicId, address _user, string memory _content) internal returns (uint) {
        require(!hasCommented[_topicId][_user], "Already commented");
        
        hasCommented[_topicId][_user] = true;
        
        // 创建评论
        comments[nextCommentId] = Comment({
            id: nextCommentId,
            topicId: _topicId,
            author: _user,
            content: _content,
            timestamp: block.timestamp,
            likeCount: 0
        });
        
        topicComments[_topicId].push(nextCommentId);
        uint currentCommentId = nextCommentId;
        nextCommentId++;
        
        return currentCommentId;
    }
    
    // 给评论点赞
    function _likeComment(uint _commentId, address _user) internal {
        require(_commentId < nextCommentId, "Comment does not exist");
        require(!hasLikedComment[_commentId][_user], "Already liked this comment");
        
        hasLikedComment[_commentId][_user] = true;
        comments[_commentId].likeCount++;
    }
    
    // 获取评论的话题ID
    function _getCommentTopicId(uint _commentId) internal view returns (uint) {
        require(_commentId < nextCommentId, "Comment does not exist");
        return comments[_commentId].topicId;
    }
    
    // 获取用户评论状态
    function _hasUserCommented(uint _topicId, address _user) internal view returns (bool) {
        return hasCommented[_topicId][_user];
    }
    
    // 获取用户是否给评论点赞
    function _hasUserLikedComment(uint _commentId, address _user) internal view returns (bool) {
        return hasLikedComment[_commentId][_user];
    }
    
    // 获取话题的评论列表
    function _getTopicComments(uint _topicId) internal view returns (uint[] memory) {
        return topicComments[_topicId];
    }
    
    // 获取评论详情
    function _getComment(uint _commentId) internal view returns (Comment memory) {
        return comments[_commentId];
    }
} 