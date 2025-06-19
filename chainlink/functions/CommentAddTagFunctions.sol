// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FunctionsClient} from "@chainlink/contracts@1.4.0/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.4.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts@1.4.0/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/resources/link-token-contracts/
 */

 /*
 这个合约已经部署在了sepolia，不需要用foundry来部署
 而且现在已经有10LINK代币的余额，可以直接用

 地址：0x590F906E2E389F114DDc06E79030caB53242b665
 Owner：0x802f71cBf691D4623374E8ec37e32e26d5f74d87
 只有Owner才可以reset，所以注意app的owner也用这个才行
 */ 

/**
 * @title CommentSentimentAnalyzer
 * @notice 使用Chainlink Functions进行评论情感分析的合约
 * @dev 通过AI分析评论情感并存储结果
 */
contract CommentSentimentAnalyzer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    // 状态变量
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // 评论ID到情感标签的映射
    mapping(uint => string) public commentTags;
    
    // 评论ID到原始评论内容的映射
    mapping(uint => string) public commentContents;
    
    // requestId到commentId的映射，用于回调时识别是哪个评论
    mapping(bytes32 => uint) public requestToCommentId;
    
    // 跟踪有效的requestId，用于验证回调
    mapping(bytes32 => bool) public validRequestIds;
    
    // 跟踪已分析的评论ID
    mapping(uint => bool) public isCommentAnalyzed;

    // 自定义错误
    error UnexpectedRequestID(bytes32 requestId);
    error CommentAlreadyAnalyzed(uint commentId);
    error CommentNotFound(uint commentId);

    // 事件
    event TagAnalysisRequested(uint indexed commentId, string comment, bytes32 requestId);
    event TagAnalysisCompleted(uint indexed commentId, string tag, bytes32 requestId);
    event CommentTagReset(uint indexed commentId);
    event AllTagsReset();

    // Router address - Hardcoded for Sepolia
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // 成功的AI JavaScript代码 - 修改为只返回POS、NEG或ERROR
    string constant AI_SOURCE = 
        "const comment = args[0];"
        "const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=AIzaSyDAxxv2iq4miqPHqXxLqwyOYTXubQWdLKQ';"
        "const body = JSON.stringify({"
        "  contents: [{ parts: [{ text: 'Classify this crypto comment as either POS (positive) or NEG (negative). Only respond with POS or NEG: ' + comment }] }]"
        "});"
        "try {"
        "  const response = await Functions.makeHttpRequest({"
        "    url: url,"
        "    method: 'POST',"
        "    headers: { 'Content-Type': 'application/json' },"
        "    data: body"
        "  });"
        "  if (response.error) return Functions.encodeString('ERROR');"
        "  const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';"
        "  if (text.includes('POS')) return Functions.encodeString('POS');"
        "  if (text.includes('NEG')) return Functions.encodeString('NEG');"
        "  return Functions.encodeString('ERROR');"
        "} catch (e) {"
        "  return Functions.encodeString('ERROR');"
        "}";

    // Gas限制设置
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    bytes32 donID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    /**
     * @notice 初始化合约
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

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
    ) external onlyOwner returns (bytes32 requestId) {
        // 检查评论是否已经分析过
        require(!isCommentAnalyzed[commentId], "Comment already analyzed");
        require(subscriptionId > 0, "Invalid subscription ID");

        // 存储评论内容
        commentContents[commentId] = comment;

        // 准备参数
        string[] memory args = new string[](1);
        args[0] = comment;

        // 创建请求
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(AI_SOURCE);
        req.setArgs(args);

        // 发送请求
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        // 记录requestId到commentId的映射
        requestToCommentId[s_lastRequestId] = commentId;
        validRequestIds[s_lastRequestId] = true;

        emit TagAnalysisRequested(commentId, comment, s_lastRequestId);

        return s_lastRequestId;
    }

    /**
     * @notice Chainlink Functions回调函数
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // 检查是否是有效的请求ID
        require(validRequestIds[requestId], "Invalid request ID");
        
        // 获取对应的commentId
        uint commentId = requestToCommentId[requestId];

        // 更新状态变量
        s_lastResponse = response;
        s_lastError = err;

        // 解析并存储分析结果
        if (err.length > 0) {
            // 如果有错误，存储ERROR标签
            commentTags[commentId] = "ERROR";
            isCommentAnalyzed[commentId] = true;
            emit TagAnalysisCompleted(commentId, "ERROR", requestId);
        } else if (response.length > 0) {
            string memory tag = string(response);
            // 验证返回的标签是否有效（POS、NEG或ERROR）
            if (keccak256(abi.encodePacked(tag)) == keccak256(abi.encodePacked("POS")) ||
                keccak256(abi.encodePacked(tag)) == keccak256(abi.encodePacked("NEG")) ||
                keccak256(abi.encodePacked(tag)) == keccak256(abi.encodePacked("ERROR"))) {
                commentTags[commentId] = tag;
            } else {
                // 如果返回了未知标签，设置为ERROR
                commentTags[commentId] = "ERROR";
            }
            isCommentAnalyzed[commentId] = true;
            emit TagAnalysisCompleted(commentId, commentTags[commentId], requestId);
        } else {
            // 如果响应为空，设置为ERROR
            commentTags[commentId] = "ERROR";
            isCommentAnalyzed[commentId] = true;
            emit TagAnalysisCompleted(commentId, "ERROR", requestId);
        }

        // 清理映射
        delete requestToCommentId[requestId];
        delete validRequestIds[requestId];
    }

    /**
     * @notice 根据评论ID获取情感分析标签
     * @param commentId 评论ID
     * @return tag 情感标签（POS/NEG/ERROR）
     */
    function getCommentTagById(uint commentId) external view returns (string memory tag) {
        require(isCommentAnalyzed[commentId], "Comment not analyzed");
        return commentTags[commentId];
    }

    /**
     * @notice 获取评论内容
     * @param commentId 评论ID
     * @return comment 原始评论内容
     */
    function getCommentContentById(uint commentId) external view returns (string memory comment) {
        return commentContents[commentId];
    }

    /**
     * @notice 检查评论是否已分析
     * @param commentId 评论ID
     * @return analyzed 是否已分析
     */
    function isAnalyzed(uint commentId) external view returns (bool analyzed) {
        return isCommentAnalyzed[commentId];
    }

    /**
     * @notice 重置指定评论的分析数据
     * @param commentId 评论ID
     */
    function resetCommentTag(uint commentId) external onlyOwner {
        delete commentTags[commentId];
        delete commentContents[commentId];
        delete isCommentAnalyzed[commentId];
        
        emit CommentTagReset(commentId);
    }

    /**
     * @notice 批量重置多个评论的分析数据
     * @param commentIds 评论ID数组
     */
    function batchResetCommentTags(uint[] calldata commentIds) external onlyOwner {
        for (uint256 i = 0; i < commentIds.length; i++) {
            uint commentId = commentIds[i];
            delete commentTags[commentId];
            delete commentContents[commentId];
            delete isCommentAnalyzed[commentId];
            
            emit CommentTagReset(commentId);
        }
    }

    /**
     * @notice 重置所有分析数据
     * @param confirmationCode 确认代码，必须为"RESET_ALL_TAGS"
     */
    function resetAllTags(string calldata confirmationCode) external onlyOwner {
        require(
            keccak256(abi.encodePacked(confirmationCode)) == 
            keccak256(abi.encodePacked("RESET_ALL_TAGS")),
            "Invalid confirmation code"
        );
        
        emit AllTagsReset();
    }

    /**
     * @notice 更新gas限制
     * @param newGasLimit 新的gas限制
     */
    function updateGasLimit(uint32 newGasLimit) external onlyOwner {
        require(newGasLimit >= 100000, "Gas limit too low");
        gasLimit = newGasLimit;
    }

    /**
     * @notice 获取最后的响应数据（调试用）
     */
    function getLastResponse() external view returns (bytes memory response, bytes memory error) {
        return (s_lastResponse, s_lastError);
    }

    /**
     * @notice 检查合约配置
     */
    function getConfig() external view returns (
        address routerAddr,
        uint32 currentGasLimit,
        bytes32 currentDonID,
        address ownerAddr
    ) {
        return (router, gasLimit, donID, owner());
    }

    /**
     * @notice 获取AI源代码（调试用）
     */
    function getAiSource() external pure returns (string memory) {
        return AI_SOURCE;
    }
}
