// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TopicManager} from "./TopicManager.sol";
import {UserManager} from "./UserManager.sol";
import {CampaignToken} from "../token/Campaign.sol";
import {TimeSerLinkArray} from "../utils/TimeSerLinkArray.sol";
import {CountSerLinkArray} from "../utils/CountSerLinkArray.sol";
import {ICampaignLotteryVRF} from "../chainlink/ICampaignLotteryVRF.sol";
import {ICommentAddTagFunctions} from "../chainlink/ICommentAddTagFunctions.sol";
import {USDC} from "../token/USDC.sol";

contract ActionManager {
    address public owner;

    // 用来校验topic是否存在
    TopicManager public topicManager;
    UserManager public userManager;
    ICampaignLotteryVRF public vrfContract;
    ICommentAddTagFunctions public commentTagFunctions;
    uint64 public functionsSubscriptionId;

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
    
    // 费用池管理
    mapping(uint => uint) public platformFeePool;           // campaignId => 平台费金额
    mapping(uint => uint) public qualityCommenterFeePool;   // campaignId => 质量评论者费用池
    mapping(uint => uint) public lotteryForLikerFeePool;    // campaignId => 点赞者抽奖费用池
    
    // 记录每个活动的点赞者（按topic分组）
    mapping(uint => mapping(uint => address[])) public topicCampaignLikers;  // topicId => campaignId => 点赞者数组
    mapping(uint => mapping(uint => mapping(address => bool))) public hasLikedInTopicCampaign; // 防重复记录
    
    // 活动结束后的分配记录
    mapping(uint => address[]) public topCommenters;        // campaignId => top评论者地址数组
    mapping(uint => address[]) public luckyLikers;          // campaignId => 幸运点赞者地址数组
    mapping(uint => bool) public rewardsDistributed;        // campaignId => 是否已分配奖励

    // 链表实例
    TimeSerLinkArray public timeSerLinkArray;
    CountSerLinkArray public countSerLinkArray;

    // 构造函数
    constructor(
        address _topicManagerAddr, 
        address _userManagerAddr,
        uint _commentRewardAmount,
        uint _likeRewardAmount,
        address _vrfContractAddr,
        address _commentTagFunctionsAddr,
        uint64 _functionsSubscriptionId
    ) {
        nextCommentId = 0;
        nextLikeId = 0;
        owner = msg.sender;
        topicManager = TopicManager(_topicManagerAddr);
        userManager = UserManager(_userManagerAddr);
        vrfContract = ICampaignLotteryVRF(_vrfContractAddr);
        commentTagFunctions = ICommentAddTagFunctions(_commentTagFunctionsAddr);
        functionsSubscriptionId = _functionsSubscriptionId;
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
        
        // 记录点赞者到所有相关活动中
        uint[] memory campaignIds = topicManager.getTopicCampaigns(_topicId);
        for (uint i = 0; i < campaignIds.length; i++) {
            uint campaignId = campaignIds[i];
            // 只有活动激活时才记录点赞者
            TopicManager.CampaignInfo memory campaignInfo = topicManager.getCampaignInfo(campaignId);
            if (campaignInfo.isActive) {
                if (!hasLikedInTopicCampaign[_topicId][campaignId][_user]) {
                    topicCampaignLikers[_topicId][campaignId].push(_user);
                    hasLikedInTopicCampaign[_topicId][campaignId][_user] = true;
                }
            }
        }
        
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

    // 查：给定用户地址address和campaignId，查询假如目前活动结束，预计可得多少钱
    function getExpectedReward(address _user, uint _campaignId) public view returns (uint) {
        // todo
    }
    
    // 活动注资时分配费用
    function allocateFundsOnCampaignFunding(uint _campaignId, uint _amount) external {
        require(msg.sender == address(topicManager), "Only TopicManager can call this function");
        
        // 计算各项费用
        uint platformFee = _amount * topicManager.platformFeePercent() / 100;
        uint qualityCommenterFee = _amount * topicManager.qualityCommenterFeePercent() / 100;
        uint lotteryFee = _amount * topicManager.lotteryForLikerFeePercent() / 100;
        
        // 分配费用到各个池子
        platformFeePool[_campaignId] += platformFee;
        qualityCommenterFeePool[_campaignId] += qualityCommenterFee;
        lotteryForLikerFeePool[_campaignId] += lotteryFee;
    }
    
    // 获取指定活动的点赞者列表
    function getCampaignLikers(uint _campaignId) public view returns (address[] memory) {
        TopicManager.CampaignInfo memory campaignInfo = topicManager.getCampaignInfo(_campaignId);
        uint topicId = campaignInfo.topicId;
        return topicCampaignLikers[topicId][_campaignId];
    }
    
    // 分配活动奖励
    function distributeRewards(uint _campaignId) external {
        require(msg.sender == address(topicManager), "Only TopicManager can call this function");
        require(!rewardsDistributed[_campaignId], "Rewards already distributed");
        
        TopicManager.CampaignInfo memory campaignInfo = topicManager.getCampaignInfo(_campaignId);
        require(!campaignInfo.isActive, "Campaign still active");
        
        // 1. 分配质量评论者奖励
        _distributeQualityCommenterRewards(_campaignId);
        
        // 2. 分配点赞者抽奖奖励
        _distributeLotteryRewards(_campaignId);
        
        rewardsDistributed[_campaignId] = true;
    }
    
    // 分配质量评论者奖励
    function _distributeQualityCommenterRewards(uint _campaignId) private {
        if (qualityCommenterFeePool[_campaignId] == 0) return;
        
        TopicManager.CampaignInfo memory campaignInfo = topicManager.getCampaignInfo(_campaignId);
        uint topicId = campaignInfo.topicId;
        uint qualityCommenterNum = topicManager.qualityCommenterNum();
        
        // 获取最高点赞评论
        uint[] memory topCommentIds = getMostLikedComments(qualityCommenterNum);
        
        // 过滤出属于该topic的评论，并获取评论者地址
        address[] memory commenterAddresses = new address[](qualityCommenterNum);
        uint validCount = 0;
        
        for (uint i = 0; i < topCommentIds.length && validCount < qualityCommenterNum; i++) {
            if (comments[topCommentIds[i]].topicId == topicId && !comments[topCommentIds[i]].isDelete) {
                commenterAddresses[validCount] = comments[topCommentIds[i]].user;
                validCount++;
            }
        }
        
        // 平分奖励
        if (validCount > 0) {
            USDC usdc = USDC(topicManager.usdc());
            uint rewardPerCommenter = qualityCommenterFeePool[_campaignId] / validCount;
            
            // 调整数组大小
            address[] memory finalCommenters = new address[](validCount);
            for (uint i = 0; i < validCount; i++) {
                finalCommenters[i] = commenterAddresses[i];
                usdc.transfer(commenterAddresses[i], rewardPerCommenter);
            }
            topCommenters[_campaignId] = finalCommenters;
        }
    }
    
    // 分配点赞者抽奖奖励
    function _distributeLotteryRewards(uint _campaignId) private {
        if (lotteryForLikerFeePool[_campaignId] == 0) return;
        
        // 获取该活动的所有点赞者
        address[] memory likers = getCampaignLikers(_campaignId);
        
        if (likers.length == 0) return;
        
        // 检查VRF是否已完成抽奖
        (bool isRequested, bool fulfilled, uint256[] memory luckyIds) = vrfContract.getCampaignLuckyIds(_campaignId);
        
        if (!isRequested) {
            // 如果VRF抽奖尚未请求，则触发抽奖
            uint qualityCommenterNum = topicManager.qualityCommenterNum();
            uint lotteryCount = likers.length < qualityCommenterNum ? likers.length : qualityCommenterNum;
            
            if (lotteryCount > 0) {
                vrfContract.setLotteryByCampaignId(_campaignId, likers.length, lotteryCount, false);
                
                // 重新获取抽奖结果
                (, fulfilled, luckyIds) = vrfContract.getCampaignLuckyIds(_campaignId);
            }
        }
        
        if (!fulfilled || luckyIds.length == 0) {
            // VRF抽奖尚未完成，暂时不分配奖励
            return;
        }
        
        // 根据VRF结果获取获奖者
        address[] memory winners = new address[](luckyIds.length);
        uint validWinners = 0;
        for (uint i = 0; i < luckyIds.length; i++) {
            if (luckyIds[i] < likers.length) {
                winners[validWinners] = likers[luckyIds[i]];
                validWinners++;
            }
        }
        
        // 调整获奖者数组大小
        address[] memory finalWinners = new address[](validWinners);
        for (uint i = 0; i < validWinners; i++) {
            finalWinners[i] = winners[i];
        }
        
        // 平分奖励
        if (validWinners > 0) {
        USDC usdc = USDC(topicManager.usdc());
            uint rewardPerWinner = lotteryForLikerFeePool[_campaignId] / validWinners;
            for (uint i = 0; i < validWinners; i++) {
                usdc.transfer(finalWinners[i], rewardPerWinner);
            }
        }
        
        luckyLikers[_campaignId] = finalWinners;
    }
    
    // 提取平台费用
    function withdrawPlatformFee(uint _campaignId, address _to) external {
        require(msg.sender == address(topicManager), "Only TopicManager can call this function");
        require(platformFeePool[_campaignId] > 0, "No platform fees to withdraw");
        
        USDC usdc = USDC(topicManager.usdc());
        uint amount = platformFeePool[_campaignId];
        platformFeePool[_campaignId] = 0;
        usdc.transfer(_to, amount);
    }
    
    // 查询奖励分配信息
    function getRewardDistributionInfo(uint _campaignId) external view returns (
        address[] memory topCommentersArray,
        address[] memory luckyLikersArray,
        bool distributed
    ) {
        return (
            topCommenters[_campaignId],
            luckyLikers[_campaignId],
            rewardsDistributed[_campaignId]
        );
    }

    // 查：给定campaignId，userId，假如现在就结束活动，我预计可得多少钱（USDC和projectToken）
    function getExpectedReward(uint _campaignId, address _user) public view returns (uint[2] memory worstCase, uint[2] memory bestCase) {
        // 获取活动信息
        TopicManager.CampaignInfo memory campaignInfo = topicManager.getCampaignInfo(_campaignId);
        
        // 如果活动不存在或已结束，则返回0
        if (_campaignId >= topicManager.nextCampaignId() || !campaignInfo.isActive) {
            return (
                [uint(0), uint(0)],  // 最差情况
                [uint(0), uint(0)]   // 最好情况
            );
        }
        
        // 获取CampaignToken地址和用户余额
        address campaignTokenAddr = topicManager.getCampaignToken(_campaignId);
        CampaignToken campaignToken = CampaignToken(campaignTokenAddr);
        uint userBalance = campaignToken.balanceOf(_user);
        
        // 如果用户没有CampaignToken，则返回0
        if (userBalance == 0) {
            return (
                [uint(0), uint(0)],  // 最差情况
                [uint(0), uint(0)]   // 最好情况
            );
        }
        
        // 计算用户通过CampaignToken获得的基础奖励（最差情况）
        uint totalSupply = campaignToken.totalSupply();
        
        // 获取活动的USDC和projectToken总量
        uint usdcAmount = campaignToken.getFundedUSDC();
        uint projectTokenAmount = campaignToken.getFundedProjectToken();
        
        // 按比例计算用户应得的奖励
        uint userUsdcReward = totalSupply > 0 ? (usdcAmount * userBalance) / totalSupply : 0;
        uint userPTokenReward = totalSupply > 0 ? (projectTokenAmount * userBalance) / totalSupply : 0;
        
        // 设置最差情况
        worstCase[0] = userUsdcReward;
        worstCase[1] = userPTokenReward;
        
        // 复制最差情况到最好情况（基础值）
        bestCase[0] = userUsdcReward;
        bestCase[1] = userPTokenReward;
        
        // 检查用户是否可能成为质量评论者
        bool isPotentialQualityCommenter = false;
        uint topicId = campaignInfo.topicId;
        
        // 获取用户在该topic下的所有评论
        uint[] memory userComments = getRecentCommentsByUserAddress(_user, 100);
        
        // 如果用户有评论，检查是否可能进入top评论者
        if (userComments.length > 0) {
            // 获取质量评论者数量
            uint qualityCommenterNum = topicManager.qualityCommenterNum();
            
            // 获取最多点赞的评论
            uint[] memory topComments = getMostLikedComments(qualityCommenterNum);
            
            // 检查用户的评论是否在top列表中
            for (uint i = 0; i < userComments.length; i++) {
                uint commentId = userComments[i];
                // 确保评论属于该topic且未删除
                if (comments[commentId].topicId == topicId && !comments[commentId].isDelete) {
                    for (uint j = 0; j < topComments.length; j++) {
                        if (commentId == topComments[j]) {
                            isPotentialQualityCommenter = true;
                            break;
                        }
                    }
                    if (isPotentialQualityCommenter) break;
                }
            }
        }
        
        // 检查用户是否可能成为点赞抽奖幸运者
        bool isPotentialLuckyLiker = false;
        
        // 检查用户是否对该活动的评论进行过点赞
        if (hasLikedInTopicCampaign[topicId][_campaignId][_user]) {
            isPotentialLuckyLiker = true;
        }
        
        // 如果用户可能成为质量评论者，添加相应奖励
        if (isPotentialQualityCommenter) {
            uint qualityCommenterFee = qualityCommenterFeePool[_campaignId];
            uint qualityCommenterNum = topicManager.qualityCommenterNum();
            
            // 计算每个质量评论者可获得的奖励
            uint qualityCommenterReward = qualityCommenterNum > 0 ? qualityCommenterFee / qualityCommenterNum : 0;
            bestCase[0] += qualityCommenterReward;
        }
        
        // 如果用户可能成为点赞抽奖幸运者，添加相应奖励
        if (isPotentialLuckyLiker) {
            uint lotteryFee = lotteryForLikerFeePool[_campaignId];
            
            // 获取该活动的所有点赞者
            address[] memory likers = getCampaignLikers(_campaignId);
            
            // 确定抽奖人数（不超过实际点赞人数）
            uint qualityCommenterNum = topicManager.qualityCommenterNum();
            uint lotteryCount = likers.length < qualityCommenterNum ? likers.length : qualityCommenterNum;
            
            // 计算每个幸运点赞者可获得的奖励
            uint lotteryReward = lotteryCount > 0 ? lotteryFee / lotteryCount : 0;
            
            // 根据概率添加奖励（简化处理，直接添加全部可能奖励）
            bestCase[0] += lotteryReward;
        }
        
        return (worstCase, bestCase);
    }

    // 查：给定campaignId，目前各个奖池各有多少钱，以及有多人分
    function getFundPoolInfo(uint _campaignId) public view returns (uint[3] memory qualityPool, uint[3] memory lotteryPool, uint[3] memory campaignPool) {
        // 如果活动不存在，则返回0
        if (_campaignId >= topicManager.nextCampaignId()) {
            return (
                [uint(0), uint(0), uint(0)],  // 质量评论者奖池
                [uint(0), uint(0), uint(0)],  // 点赞抽奖奖池
                [uint(0), uint(0), uint(0)]   // CampaignToken奖池
            );
        }
        
        // 获取CampaignToken地址
        address campaignTokenAddr = topicManager.getCampaignToken(_campaignId);
        CampaignToken campaignToken = CampaignToken(campaignTokenAddr);
        
        // 获取质量评论者数量
        uint qualityCommenterNum = topicManager.qualityCommenterNum();
        
        // 获取质量评论者奖池中的USDC数量
        uint qualityCommenterFee = qualityCommenterFeePool[_campaignId];
        
        // 获取点赞抽奖奖池中的USDC数量
        uint lotteryFee = lotteryForLikerFeePool[_campaignId];
        
        // 获取该活动的所有点赞者
        address[] memory likers = getCampaignLikers(_campaignId);
        
        // 确定抽奖人数（不超过实际点赞人数）
        uint lotteryCount = likers.length < qualityCommenterNum ? likers.length : qualityCommenterNum;
        
        // 获取活动的USDC和projectToken总量
        uint campaignUsdcAmount = campaignToken.getFundedUSDC();
        uint campaignPTokenAmount = campaignToken.getFundedProjectToken();
        
        // 获取评论者和点赞者总数（简化计算，可能有重复）
        uint totalParticipants = getGlobalCommentsCount() + likers.length;
        
        // 设置质量评论者奖池信息
        qualityPool[0] = qualityCommenterNum;
        qualityPool[1] = qualityCommenterFee;
        qualityPool[2] = 0; // 质量评论者奖池中没有项目代币
        
        // 设置点赞抽奖奖池信息
        lotteryPool[0] = lotteryCount;
        lotteryPool[1] = lotteryFee;
        lotteryPool[2] = 0; // 点赞抽奖奖池中没有项目代币
        
        // 设置CampaignToken奖池信息
        campaignPool[0] = totalParticipants;
        campaignPool[1] = campaignUsdcAmount;
        campaignPool[2] = campaignPTokenAmount;
        
        return (qualityPool, lotteryPool, campaignPool);
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

    // ========== AI 标签功能 ==========

    /**
     * @notice 为评论添加AI情感分析标签
     * @param commentId 评论ID
     * @return success 请求是否成功发送
     */
    function addCommentAITag(uint commentId) public returns (bool) {
        // 检查评论是否存在
        require(commentId < nextCommentId, "Comment does not exist");
        require(!comments[commentId].isDelete, "Comment is deleted");
        
        // 检查评论是否已经分析过
        if (isCommentTagAnalyzed(commentId)) {
            return false; // 已分析过，不重复请求
        }
        
        // 调用Functions合约进行分析
        try commentTagFunctions.addTag(commentId, comments[commentId].content, functionsSubscriptionId) returns (bytes32) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @notice 检查评论是否已完成AI情感分析
     * @param commentId 评论ID
     * @return analyzed 是否已分析
     */
    function isCommentTagAnalyzed(uint commentId) public view returns (bool) {
        try commentTagFunctions.isAnalyzed(commentId) returns (bool analyzed) {
            return analyzed;
        } catch {
            return false;
        }
    }

    /**
     * @notice 获取评论的AI情感标签
     * @param commentId 评论ID
     * @return tag 情感标签（POS/NEG/NEU）
     */
    function getCommentAITag(uint commentId) public view returns (string memory) {
        require(isCommentTagAnalyzed(commentId), "Comment not analyzed yet");
        
        try commentTagFunctions.getCommentTagById(commentId) returns (string memory tag) {
            return tag;
        } catch {
            return "ERROR";
        }
    }

    /**
     * @notice 检查评论是否需要添加AI标签
     * @param commentId 评论ID
     * @return needsTag 是否需要添加标签
     */
    function checkCommentTagStatus(uint commentId) public view returns (bool) {
        // 检查评论是否存在
        if (commentId >= nextCommentId) {
            return false;
        }
        
        // 检查评论是否已删除
        if (comments[commentId].isDelete) {
            return false;
        }
        
        // 检查是否已分析
        return !isCommentTagAnalyzed(commentId);
    }

    /**
     * @notice 设置Functions订阅ID
     * @param _subscriptionId 新的订阅ID
     */
    function setFunctionsSubscriptionId(uint64 _subscriptionId) public {
        require(msg.sender == owner, "Only owner can call this function");
        functionsSubscriptionId = _subscriptionId;
    }

    // ========== Chainlink Automation 集成 ==========

    /**
     * @notice 检查活动是否需要执行抽奖
     * @param campaignId 活动ID
     * @return needsLottery 是否需要执行抽奖
     */
    function checkCampaignLotteryNeeded(uint256 campaignId) public view returns (bool) {
        // 检查活动是否存在
        if (campaignId >= topicManager.nextCampaignId()) {
            return false;
        }
        
        TopicManager.CampaignInfo memory campaignInfo = topicManager.getCampaignInfo(campaignId);
        
        // 检查活动是否已结束
        if (campaignInfo.isActive || block.timestamp < campaignInfo.endTime) {
            return false;
        }
        
        // 检查是否已经抽奖
        (bool isRequested, , ) = vrfContract.getCampaignLuckyIds(campaignId);
        return !isRequested;
    }

    /**
     * @notice 执行活动抽奖
     * @param campaignId 活动ID
     * @return success 操作是否成功
     */
    function performCampaignLottery(uint256 campaignId) public returns (bool) {
        if (!checkCampaignLotteryNeeded(campaignId)) {
            return false;
        }
        
        // 获取活动参与者数量（点赞者）
        address[] memory likers = getCampaignLikers(campaignId);
        uint256 participantCount = likers.length;
        
        if (participantCount == 0) {
            return false;
        }
        
        // 执行抽奖，选择前5名或参与者数量（取较小值）
        uint256 qualityCommenterNum = topicManager.qualityCommenterNum();
        uint256 winnerCount = participantCount < qualityCommenterNum ? participantCount : qualityCommenterNum;
        
        try vrfContract.setLotteryByCampaignId(campaignId, participantCount, winnerCount, false) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @notice 检查指定范围内需要添加标签的评论
     * @param startId 起始评论ID
     * @param endId 结束评论ID
     * @return commentIds 需要添加标签的评论ID数组
     */
    function checkNewCommentsForTagging(uint256 startId, uint256 endId) public view returns (uint256[] memory) {
        // 确保ID范围有效
        uint256 validEndId = endId;
        if (validEndId >= nextCommentId) {
            validEndId = nextCommentId > 0 ? nextCommentId - 1 : 0;
        }
        
        if (startId > validEndId || nextCommentId == 0) {
            return new uint256[](0);
        }
        
        // 第一次遍历计算需要标签的评论数量
        uint256 count = 0;
        for (uint256 i = startId; i <= validEndId; i++) {
            if (checkCommentTagStatus(i)) {
                count++;
            }
        }
        
        // 创建结果数组
        uint256[] memory result = new uint256[](count);
        
        // 第二次遍历填充结果数组
        uint256 index = 0;
        for (uint256 i = startId; i <= validEndId; i++) {
            if (checkCommentTagStatus(i)) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }

    /**
     * @notice 批量为评论添加AI标签
     * @param commentIds 评论ID数组
     * @return successCount 成功添加标签请求的评论数量
     */
    function performBatchCommentTagging(uint256[] memory commentIds) public returns (uint256) {
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < commentIds.length; i++) {
            if (addCommentAITag(commentIds[i])) {
                successCount++;
            }
        }
        
        return successCount;
    }

    /**
     * @notice 获取评论总数（用于Automation批处理）
     * @return count 当前评论总数
     */
    function getCommentCounter() public view returns (uint256) {
        return nextCommentId;
    }

    // ========== 配置管理 ==========

    /**
     * @notice 设置VRF合约地址
     * @param _vrfContractAddr 新的VRF合约地址
     */
    function setVrfContract(address _vrfContractAddr) public {
        require(msg.sender == owner, "Only owner can call this function");
        vrfContract = ICampaignLotteryVRF(_vrfContractAddr);
    }

    /**
     * @notice 设置评论标签Functions合约地址
     * @param _commentTagFunctionsAddr 新的Functions合约地址
     */
    function setCommentTagFunctions(address _commentTagFunctionsAddr) public {
        require(msg.sender == owner, "Only owner can call this function");
        commentTagFunctions = ICommentAddTagFunctions(_commentTagFunctionsAddr);
    }
} 