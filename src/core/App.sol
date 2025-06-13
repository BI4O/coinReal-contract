// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UserManager.sol";
import "./TopicManager.sol";
import "./ActionManager.sol";

contract App {
    // 使用组合模式而不是继承
    UserManager public userManager;
    TopicManager public topicManager;  // TopicManager已经继承了TopicBaseManager
    ActionManager public actionManager;
    
    // 权限控制
    address public admin;
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    modifier onlyRegisteredUser() {
        require(userManager._getUser(msg.sender).registered, "User not registered");
        _;
    }
    
    constructor(
        address _userManager,
        address _topicManager,
        address _actionManager,
        address _admin
    ) {
        userManager = UserManager(_userManager);
        topicManager = TopicManager(_topicManager);
        actionManager = ActionManager(_actionManager);
        admin = _admin;
    }
    
    // 设置CampaignFactory
    function setCampaignFactory(address _factory) external onlyAdmin {
        topicManager._setCampaignFactory(_factory);
    }
    
    // 设置奖励
    function setRewards(uint _commentReward, uint _likeReward) external onlyAdmin {
        topicManager._setRewards(_commentReward, _likeReward);
    }
    
    // 用户管理函数
    function registerUser(
        string memory _name, 
        string memory _bio, 
        string memory _email
    ) external {
        userManager._registerUser(msg.sender, _name, _bio, _email);
    }
    
    function updateUser(
        string memory _name, 
        string memory _bio, 
        string memory _email
    ) external onlyRegisteredUser {
        userManager._updateUser(msg.sender, _name, _bio, _email);
    }
    
    function getUser(address _user) external view returns (UserManager.User memory) {
        return userManager._getUser(_user);
    }
    
    function getUserById(uint _id) external view returns (UserManager.User memory) {
        return userManager._getUserById(_id);
    }
    
    function deleteUser(address _user) external onlyAdmin {
        userManager._deleteUser(_user);
    }
    
    // 话题管理函数（直接使用TopicManager，它继承了TopicBaseManager）
    function registerTopic(
        string memory _name, 
        string memory _description, 
        string memory _tokenAddress,
        uint _tokenPrice
    ) external onlyAdmin {
        topicManager._registerTopic(_name, _description, _tokenAddress, _tokenPrice);
    }
    
    function getTopic(uint _topicId) external view returns (TopicManager.Topic memory) {
        return topicManager._getTopic(_topicId);
    }
    
    function getTopicByTokenAddress(string memory _tokenAddress) external view returns (TopicManager.Topic memory) {
        return topicManager._getTopicByTokenAddress(_tokenAddress);
    }
    
    function listTopics() external view returns (TopicManager.Topic[] memory) {
        return topicManager.listTopics();
    }
    
    function updateTopicTokenPrice(uint _topicId, uint _tokenPrice) external onlyAdmin {
        topicManager._updateTopicTokenPrice(_topicId, _tokenPrice);
    }
    
    // TODO：通过chainlinkAutomation + DataFeed更新Topic的项目的价格
    function updateTopicTokenPriceAuto(uint _topicId) public {
        topicManager._updateTopicTokenPriceAuto(_topicId);
    }
    
    function deleteTopic(uint _topicId) external onlyAdmin {
        topicManager._deleteTopic(_topicId);
    }
    
    // Campaign管理函数（TopicManager）
    // 注册完成后生成一个TopicId，需要用这个Id来去继续启动Campaign
    function registerCampaign(
        address _sponsor,
        uint _topicId,
        string memory _name,
        string memory _description
    ) external onlyAdmin returns (bool, uint) {
        return topicManager._registerCampaign(_sponsor, _topicId, _name, _description);
    }
    
    // 启动Campaign，需要事先转USDC或者大于最小美金价值1000的projectToken
    function startCampaign(uint _campaignId, uint _duration) external onlyAdmin {
        topicManager._startCampaign(_campaignId, _duration);
    }
    
    function endCampaign(uint _campaignId) external onlyAdmin {
        topicManager._endCampaign(_campaignId);
    }
    
    // TODO：通过chainlinkAutomation + DataFeed更新项目代币的价格，如果低于1.1倍承诺奖池，则自动结束Campaign
    function endCampaignByLowProjectTokenPrice(uint _campaignId) external onlyAdmin {
        topicManager._endCampaignByLowProjectTokenPrice(_campaignId);
    }
    
    // 用户行为函数（ActionManager + TopicManager mint）
    function commentOnTopic(uint _topicId, string memory _content) external onlyRegisteredUser {
        // 添加评论
        uint commentId = actionManager._addComment(_topicId, msg.sender, _content);
        
        // 增加话题评论数 - 通过TopicManager验证话题存在
        TopicManager.Topic memory topic = topicManager._getTopic(_topicId);
        require(bytes(topic.name).length > 0, "Topic not exist");
        
        // mint奖励代币
        topicManager._commentOnTopicIdMint(_topicId, msg.sender);
    }
    
    function likeComment(uint _commentId) external onlyRegisteredUser {
        // 获取评论的话题ID
        uint topicId = actionManager._getCommentTopicId(_commentId);
        
        // 点赞评论
        actionManager._likeComment(_commentId, msg.sender);
        
        // mint奖励代币
        topicManager._likeCommentMint(topicId, msg.sender);
    }
    
    function unlikeComment(uint _commentId) external onlyRegisteredUser {
        actionManager._unlikeComment(_commentId, msg.sender);
    }
    
    // 查询函数
    function hasUserCommented(uint _topicId, address _user) external view returns (bool) {
        return actionManager._hasUserCommented(_topicId, _user);
    }
    
    function hasUserLikedComment(uint _commentId, address _user) external view returns (bool) {
        return actionManager._hasUserLikedComment(_commentId, _user);
    }
    
    function getTopicComments(uint _topicId) external view returns (uint[] memory) {
        return actionManager._getTopicComments(_topicId);
    }
    
    function getComment(uint _commentId) external view returns (ActionManager.Comment memory) {
        return actionManager._getComment(_commentId);
    }
    
    // 获取各Manager的状态变量
    function getNextUserId() external view returns (uint) {
        return userManager.nextUserId();
    }
    
    function getNextTopicId() external view returns (uint) {
        return topicManager.nextTopicId();
    }
    
    function getNextCommentId() external view returns (uint) {
        return actionManager.nextCommentId();
    }
    
    function getNextCampaignId() external view returns (uint) {
        return topicManager.nextCampaignId();
    }
    
    function getCampaignInfo(uint _campaignId) external view returns (TopicManager.CampaignInfo memory) {
        return topicManager._getCampaignInfo(_campaignId);
    }
    
    function getCampaignToken(uint _campaignId) external view returns (address) {
        return topicManager.campaigns(_campaignId);
    }
    
    function getTopicCampaigns(uint _topicId) external view returns (uint[] memory) {
        return topicManager._getTopicCampaigns(_topicId);
    }
} 