// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title ICommentAddTagFunctions
 * @dev CommentSentimentAnalyzer合约的接口定义
 * 部署在Sepolia测试网: 0x8a000e20bEc0c5627B5898376A8f6FEfCf79baC9
 */
interface ICommentAddTagFunctions {
    /**
     * @dev 请求情感分析事件
     */
    event TagAnalysisRequested(uint indexed commentId, string comment, bytes32 requestId);
    
    /**
     * @dev 情感分析完成事件
     */
    event TagAnalysisCompleted(uint indexed commentId, string tag, bytes32 requestId);
    
    /**
     * @dev 评论标签重置事件
     */
    event CommentTagReset(uint indexed commentId);
    
    /**
     * @dev 所有标签重置事件
     */
    event AllTagsReset();

    /**
     * @notice 为评论添加AI情感分析标签
     * @param commentId 评论ID
     * @param comment 评论内容
     * @param subscriptionId Chainlink Functions订阅ID
     * @return requestId 请求ID
     */
    function addTag(
        uint commentId,
        string calldata comment,
        uint64 subscriptionId
    ) external returns (bytes32 requestId);

    /**
     * @notice 根据评论ID获取情感分析标签
     * @param commentId 评论ID
     * @return tag 情感标签（POS/NEG/NEU）
     */
    function getCommentTagById(uint commentId) external view returns (string memory tag);

    /**
     * @notice 获取评论内容
     * @param commentId 评论ID
     * @return comment 原始评论内容
     */
    function getCommentContentById(uint commentId) external view returns (string memory comment);

    /**
     * @notice 检查评论是否已分析
     * @param commentId 评论ID
     * @return analyzed 是否已分析
     */
    function isAnalyzed(uint commentId) external view returns (bool analyzed);

    /**
     * @notice 重置指定评论的分析数据
     * @param commentId 评论ID
     */
    function resetCommentTag(uint commentId) external;

    /**
     * @notice 批量重置多个评论的分析数据
     * @param commentIds 评论ID数组
     */
    function batchResetCommentTags(uint[] calldata commentIds) external;

    /**
     * @notice 重置所有分析数据
     * @param confirmationCode 确认代码，必须为"RESET_ALL_TAGS"
     */
    function resetAllTags(string calldata confirmationCode) external;

    /**
     * @notice 更新gas限制
     * @param newGasLimit 新的gas限制
     */
    function updateGasLimit(uint32 newGasLimit) external;

    /**
     * @notice 获取最后的响应数据（调试用）
     */
    function getLastResponse() external view returns (bytes memory response, bytes memory error);

    /**
     * @notice 检查合约配置
     */
    function getConfig() external view returns (
        address routerAddr,
        uint32 currentGasLimit,
        bytes32 currentDonID,
        address ownerAddr
    );
} 