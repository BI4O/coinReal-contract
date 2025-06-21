// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IActionManager
 * @notice 用户交互管理接口
 */
interface IActionManager {
    // 评论结构体
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

    // 点赞结构体
    struct Like {
        uint id;
        address user;
        uint topicId;   
        uint timestamp;

        // 特殊属性
        uint commentId;
        bool isCancel;
    }
    
    // 查询函数
    function owner() external view returns (address);
    function nextCommentId() external view returns (uint);
    function nextLikeId() external view returns (uint);
    function commentRewardAmount() external view returns (uint);
    function commentRewardExtraAmount() external view returns (uint);
    function likeRewardAmount() external view returns (uint);
    function comments(uint id) external view returns (Comment memory);
    function likes(uint id) external view returns (Like memory);
    function hasLiked(uint commentId, address user) external view returns (bool);
    function commentToTokenRewardBalances(uint commentId, uint campaignId) external view returns (uint);
    
    // 管理函数
    function setOwner(address _owner) external;
    
    // 用户交互
    function addTags(uint commentId, string[] memory tags) external;
    function addComment(uint _topicId, address _user, string memory _content) external returns (bool, uint);
    function addLike(uint _topicId, uint _commentId, address _user) external returns (bool, uint);
    function deleteCommentByUser(uint _commentId, address _user) external returns (bool);
    function deleteCommentByAdmin(uint _commentId) external returns (bool);
    
    // 查询功能
    function getComment(uint _commentId) external view returns (Comment memory);
    function getLike(uint _likeId) external view returns (Like memory);
    function getLikeCount(uint _commentId) external view returns (uint);
    function getCommentTags(uint _commentId) external view returns (string[] memory);
    function getRecentCommentsByUserAddress(address _user, uint _n) external view returns (uint[] memory);
    function getRecentLikesByUserAddress(address _user, uint _n) external view returns (uint[] memory);
    function getMostLikedComments(uint _n) external view returns (uint[] memory);
    function getLeastLikedComments(uint _n) external view returns (uint[] memory);
    function getMostLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getRecentCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getRecentLikesPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getValidCommentsCount() external view returns (uint);
    function getGlobalCommentsCount() external view returns (uint);
    function getGlobalLikesCount() external view returns (uint);
    
    // 奖励功能
    function allocateFundsOnCampaignFunding(uint _campaignId, uint _amount) external;
    function distributeRewards(uint _campaignId) external returns (bool);
    
    // AI标签功能
    function addCommentAITag(uint commentId) external returns (bool);
    function isCommentTagAnalyzed(uint commentId) external view returns (bool);
    function getCommentAITag(uint commentId) external view returns (string memory);
    function checkCommentTagStatus(uint commentId) external view returns (bool);
    
    // Chainlink Automation功能
    function checkCampaignLotteryNeeded(uint256 campaignId) external view returns (bool);
    function performCampaignLottery(uint256 campaignId) external returns (bool);
    function checkNewCommentsForTagging(uint256 startId, uint256 endId) external view returns (uint256[] memory);
    function performBatchCommentTagging(uint256[] memory commentIds) external returns (uint256);
    function getCommentCounter() external view returns (uint256);
    
    // 奖励查询
    function getExpectedReward(uint256 campaignId, address user) external view returns (uint[2] memory, uint[2] memory);
    function getFundPoolInfo(uint256 campaignId) external view returns (uint[3] memory, uint[3] memory, uint[3] memory);
} 