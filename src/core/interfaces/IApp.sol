// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IUserManager.sol";
import "./ITopicManager.sol";
import "./IActionManager.sol";
import "../../token/interfaces/IUSDC.sol";
import "../../token/interfaces/IProjectToken.sol";
import "../../token/interfaces/ICampaignFactory.sol";
import "../../chainlink/ICampaignLotteryVRF.sol";

/**
 * @title IApp
 * @notice App合约的接口定义，包含所有公共函数
 */
interface IApp {
    // // 查询组件地址
    // function userManager() external view returns (UserManager);
    // function topicManager() external view returns (TopicManager);
    // function actionManager() external view returns (ActionManager);
    // function usdc() external view returns (USDC);
    // function projectToken() external view returns (ProjectToken);
    // function campaignFactory() external view returns (CampaignFactory);
    // function vrfContract() external view returns (ICampaignLotteryVRF);
    function owner() external view returns (address);
    
    // 管理功能
    function setActionManager() external;
    
    // 用户功能
    function registerUser(string memory _name, string memory _bio, string memory _email) external;
    
    // 话题和活动管理
    function registerTopic(string memory _name, string memory _description, string memory _tokenAddress, uint _tokenPrice) external;
    function registerCampaign(address _sponsor, uint _topicId, string memory _name, string memory _description, address _projectTokenAddr) external;
    function fundCampaignWithUSDC(uint _campaignId, uint _amount) external;
    function fundCampaignWithProjectToken(uint _campaignId, uint _amount) external;
    function startCampaign(uint _campaignId, uint _endTime) external;
    function endCampaign(uint _campaignId) external;
    
    // 互动功能
    function like(uint _topicId, uint _commentId) external;
    function comment(uint _topicId, string memory _content) external;
    
    // 查询功能 - 用户活动
    function getUserRecentComments(address _userAddress, uint _n) external view returns (uint[] memory);
    function getUserRecentLikes(address _userAddress, uint _n) external view returns (uint[] memory);
    
    // 查询功能 - 热门评论
    function getMostLikedComments(uint _n) external view returns (uint[] memory);
    function getLeastLikedComments(uint _n) external view returns (uint[] memory);
    function getMostLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    
    // 查询功能 - 时间序列
    function getRecentCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getRecentLikesPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    
    // 查询功能 - 统计
    function getValidCommentsCount() external view returns (uint);
    function getGlobalCommentsCount() external view returns (uint);
    function getGlobalLikesCount() external view returns (uint);
    
    // 查询功能 - 详情
    function getComment(uint _commentId) external view returns (IActionManager.Comment memory);
    function getLike(uint _likeId) external view returns (IActionManager.Like memory);
    function getCommentLikeCount(uint _commentId) external view returns (uint);
    function getCommentTags(uint _commentId) external view returns (string[] memory);
    
    // 管理功能
    function addCommentTags(uint _commentId, string[] memory _tags) external;
    function deleteComment(uint _commentId) external;
    function withdrawPlatformFees(uint _campaignId) external;
    function getRewardDistributionInfo(uint _campaignId) external view returns (
        address[] memory topCommenters,
        address[] memory luckyLikers,
        bool distributed
    );
    
    // AI 标签功能
    function addCommentAITag(uint commentId) external returns (bool);
    function isCommentTagAnalyzed(uint commentId) external view returns (bool);
    function getCommentAITag(uint commentId) external view returns (string memory);
    function checkCommentTagStatus(uint commentId) external view returns (bool);
    
    // Chainlink Automation 功能
    function checkCampaignLotteryNeeded(uint256 campaignId) external view returns (bool);
    function performCampaignLottery(uint256 campaignId) external returns (bool);
    function checkNewCommentsForTagging(uint256 startId, uint256 endId) external view returns (uint256[] memory);
    function performBatchCommentTagging(uint256[] memory commentIds) external returns (uint256);
    function getCommentCounter() external view returns (uint256);
    
    // 查询预期奖励和奖池信息
    function getExpectedReward(uint256 campaignId, address user) external view returns (uint[2] memory, uint[2] memory);
    function getFundPoolInfo(uint256 campaignId) external view returns (uint[3] memory, uint[3] memory, uint[3] memory);
} 