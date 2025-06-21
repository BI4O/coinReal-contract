// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITopicItem
 * @notice 话题项目管理接口
 */
interface ITopicItem {
    // 话题结构体
    struct Topic {
        uint id;                    // 项目id
        string name;                // 项目名称
        string description;         // 项目描述
        string tokenAddress;        // 项目token地址
        uint tokenPrice;            // 项目token价格
        address dataFeed;           // 数据源地址
        uint commentCount;          // 评论数
        uint likeCount;             // 点赞数
    }
    
    // 查询函数
    function nextTopicId() external view returns (uint);
    function topics(uint id) external view returns (Topic memory);
    function topicsByTokenAddress(string memory tokenAddress) external view returns (Topic memory);
    
    // 话题操作
    function registerTopic(string memory _name, string memory _description, string memory _tokenAddress, uint _tokenPrice) external;
    function getTopic(uint _topicId) external view returns (Topic memory);
    function getTopicByTokenAddress(string memory _tokenAddress) external view returns (Topic memory);
    function listTopics() external view returns (Topic[] memory);
    function updateTopicTokenPrice(uint _topicId, uint _tokenPrice) external;
    function updateTopicTokenPriceAuto(uint _topicId) external;
    function deleteTopicToken(uint _topicId) external;
} 