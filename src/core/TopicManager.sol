// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TopicManager {
    // 话题/栏目
    uint public nextTopicId;
    struct Topic {
        uint id;                    // 项目id
        string name;                // 项目名称
        string description;         // 项目描述
        string tokenAddress;       // 项目token地址
        uint tokenPrice;            // 项目token价格
        uint commentCount;          // 评论数
        uint likeCount;             // 点赞数
    }
    // 根据id获取话题
    mapping(uint => Topic) public topics;
    // 根据tokenAddress获取话题
    mapping(string => Topic) public topicsByTokenAddress;

    // 注册话题，管理员才可以注册
    function _registerTopic(
        string memory _name, 
        string memory _description, 
        string memory _tokenAddress
    ) internal {
        topics[nextTopicId] = Topic({
            id: nextTopicId,
            name: _name,
            description: _description,
            tokenAddress: _tokenAddress,
            tokenPrice: 0,
            commentCount: 0,
            likeCount: 0
        });
        topicsByTokenAddress[_tokenAddress] = topics[nextTopicId];
        nextTopicId++;
    }
    // 手动更新话题的token价格
    function _updateTopicTokenPrice(string memory _topicTokenAddress, uint _tokenPrice) internal {
        topicsByTokenAddress[_topicTokenAddress].tokenPrice = _tokenPrice;
    }
    
    // TODO: 自动更新话题的token价格
    function _updateTopicTokenPriceAuto(string memory _topicTokenAddress) internal {
        // chainlink-datafeed
        topicsByTokenAddress[_topicTokenAddress].tokenPrice = 0;
    }

    // 根据id获取话题
    function _getTopic(uint _topicId) internal view returns (Topic memory) {
        return topics[_topicId];
    }

    // 列出所有话题
    function listTopics() public view returns (Topic[] memory) {
        Topic[] memory topicsList = new Topic[](nextTopicId);
        for (uint i = 0; i < nextTopicId; i++) {
            topicsList[i] = topics[i];
        }
        return topicsList;
    }
}