// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UserManager.sol";
import "./TopicManager.sol";
import "./ActionManager.sol";
import {USDC} from "../token/USDC.sol";
import {ProjectToken} from "../token/ProjectToken.sol";
import {CampaignFactory} from "../token/CampaignFactory.sol";
import {ICampaignLotteryVRF} from "../chainlink/ICampaignLotteryVRF.sol";

contract App {
    // 使用组合模式而不是继承
    UserManager public userManager;
    TopicManager public topicManager;  // TopicManager已经继承了TopicItem
    ActionManager public actionManager;
    USDC public usdc;
    ProjectToken public projectToken;
    CampaignFactory public campaignFactory;
    ICampaignLotteryVRF public vrfContract;
    
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
        address _actionManager,
        address _vrfContractAddr
    ) {
        owner = msg.sender;
        usdc = USDC(_usdcAddr);
        userManager = UserManager(_userManager);
        topicManager = TopicManager(_topicManager);
        actionManager = ActionManager(_actionManager);
        vrfContract = ICampaignLotteryVRF(_vrfContractAddr);
    }
    
    // 设置ActionManager引用（需要在转移owner后调用）
    function setActionManager() public onlyAdmin {
        topicManager.setActionManager(address(actionManager));
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
        // 先将USDC转到App合约，然后由TopicManager处理费用分配
        usdc.transferFrom(msg.sender, address(this), _amount);
        usdc.approve(address(topicManager), _amount);
        topicManager.fundCampaignWithUSDC(_campaignId, _amount);
    }

    // 活动注资
    function fundCampaignWithProjectToken(uint _campaignId, uint _amount) public {
        // 先将项目代币转到App合约，然后由TopicManager处理
        ProjectToken ptoken = ProjectToken(topicManager.getCampaignInfo(_campaignId).projectTokenAddr);
        ptoken.transferFrom(msg.sender, address(this), _amount);
        ptoken.approve(address(topicManager), _amount);
        topicManager.fundCampaignWithProjectToken(_campaignId, _amount);
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

    // 分页获取最近的评论ID（全局时间序列）
    function getRecentCommentsPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return actionManager.getRecentCommentsPaginated(startIndex, length);
    }

    // 分页获取最近的点赞ID（全局时间序列）
    function getRecentLikesPaginated(uint startIndex, uint length) public view returns (uint[] memory) {
        return actionManager.getRecentLikesPaginated(startIndex, length);
    }

    // 获取有效评论总数
    function getValidCommentsCount() public view returns (uint) {
        return actionManager.getValidCommentsCount();
    }

    // 获取全局评论总数（用于时间序列分页计算）
    function getGlobalCommentsCount() public view returns (uint) {
        return actionManager.getGlobalCommentsCount();
    }

    // 获取全局点赞总数（用于时间序列分页计算）
    function getGlobalLikesCount() public view returns (uint) {
        return actionManager.getGlobalLikesCount();
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
    
    // 提取平台费用（只有管理员可以）
    function withdrawPlatformFees(uint _campaignId) public onlyAdmin {
        // 先提取到App合约
        topicManager.withdrawPlatformFee(_campaignId);
        // 然后转账给App的owner
        uint balance = usdc.balanceOf(address(this));
        if (balance > 0) {
            usdc.transfer(owner, balance);
        }
    }
    
    // 查询活动的奖励分配状态
    function getRewardDistributionInfo(uint _campaignId) public view returns (
        address[] memory topCommenters,
        address[] memory luckyLikers,
        bool distributed
    ) {
        return topicManager.getRewardDistributionInfo(_campaignId);
    }

    // ========== AI 标签功能 ==========

    /**
     * @notice 为评论添加AI情感分析标签
     * @param commentId 评论ID
     * @return success 请求是否成功发送
     */
    function addCommentAITag(uint commentId) public returns (bool) {
        return actionManager.addCommentAITag(commentId);
    }

    /**
     * @notice 检查评论是否已完成AI情感分析
     * @param commentId 评论ID
     * @return analyzed 是否已分析
     */
    function isCommentTagAnalyzed(uint commentId) public view returns (bool) {
        return actionManager.isCommentTagAnalyzed(commentId);
    }

    /**
     * @notice 获取评论的AI情感标签
     * @param commentId 评论ID
     * @return tag 情感标签（POS/NEG/NEU）
     */
    function getCommentAITag(uint commentId) public view returns (string memory) {
        return actionManager.getCommentAITag(commentId);
    }

    /**
     * @notice 检查评论是否需要添加AI标签
     * @param commentId 评论ID
     * @return needsTag 是否需要添加标签
     */
    function checkCommentTagStatus(uint commentId) public view returns (bool) {
        return actionManager.checkCommentTagStatus(commentId);
    }

    // ========== Chainlink Automation 功能 ==========

    /**
     * @notice 检查活动是否需要执行抽奖
     * @param campaignId 活动ID
     * @return needsLottery 是否需要执行抽奖
     */
    function checkCampaignLotteryNeeded(uint256 campaignId) public view returns (bool) {
        return actionManager.checkCampaignLotteryNeeded(campaignId);
    }

    /**
     * @notice 执行活动抽奖
     * @param campaignId 活动ID
     * @return success 操作是否成功
     */
    function performCampaignLottery(uint256 campaignId) public returns (bool) {
        return actionManager.performCampaignLottery(campaignId);
    }

    /**
     * @notice 检查指定范围内需要添加标签的评论
     * @param startId 起始评论ID
     * @param endId 结束评论ID
     * @return commentIds 需要添加标签的评论ID数组
     */
    function checkNewCommentsForTagging(uint256 startId, uint256 endId) public view returns (uint256[] memory) {
        return actionManager.checkNewCommentsForTagging(startId, endId);
    }

    /**
     * @notice 批量为评论添加AI标签
     * @param commentIds 评论ID数组
     * @return successCount 成功添加标签请求的评论数量
     */
    function performBatchCommentTagging(uint256[] memory commentIds) public returns (uint256) {
        return actionManager.performBatchCommentTagging(commentIds);
    }

    /**
     * @notice 获取评论总数（用于Automation批处理）
     * @return count 当前评论总数
     */
    function getCommentCounter() public view returns (uint256) {
        return actionManager.getCommentCounter();
    }

    // ========== 查询预期奖励和奖池信息 ==========

    /**
     * @notice 获取用户预期奖励
     * @param campaignId 活动ID
     * @param user 用户地址
     * @return worstCase 最差情况奖励 [USDC, ProjectToken]
     * @return bestCase 最好情况奖励 [USDC, ProjectToken]
     */
    function getExpectedReward(uint256 campaignId, address user) public view returns (uint[2] memory, uint[2] memory) {
        return actionManager.getExpectedReward(campaignId, user);
    }

    /**
     * @notice 获取活动奖池信息
     * @param campaignId 活动ID
     * @return qualityPool 质量评论者奖池 [人数, USDC, ProjectToken]
     * @return lotteryPool 点赞抽奖奖池 [人数, USDC, ProjectToken]
     * @return campaignPool CampaignToken奖池 [总参与者, USDC, ProjectToken]
     */
    function getFundPoolInfo(uint256 campaignId) public view returns (uint[3] memory, uint[3] memory, uint[3] memory) {
        return actionManager.getFundPoolInfo(campaignId);
    }
}