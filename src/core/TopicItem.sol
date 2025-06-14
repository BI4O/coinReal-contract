// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
话题表
1. 话题id
2. 话题名称
3. 话题描述
4. 话题token地址
5. 话题token价格
6. 话题评论数
7. 话题点赞数
*/

// 单个话题的管理器
contract TopicItem {

    // 话题/栏目
    uint public nextTopicId;
    struct Topic {
        uint id;                    // 项目id
        string name;                // 项目名称
        string description;         // 项目描述
        string tokenAddress;       // 项目token地址
        uint tokenPrice;            // 项目token价格
        address dataFeed;           // 数据源地址
        uint commentCount;          // 评论数
        uint likeCount;             // 点赞数
    }
    // 根据id获取话题
    mapping(uint => Topic) public topics;
    // 根据tokenAddress获取话题
    mapping(string => Topic) public topicsByTokenAddress;

    // 增：话题注册，管理员才可以注册
    function registerTopic(
        string memory _name, 
        string memory _description, 
        string memory _tokenAddress,
        uint _tokenPrice
    ) public {
        topics[nextTopicId] = Topic({
            id: nextTopicId,
            name: _name,
            description: _description,
            tokenAddress: _tokenAddress,
            tokenPrice: _tokenPrice,  // 初始化价格
            dataFeed: address(0), // 默认数据源地址为0
            commentCount: 0,
            likeCount: 0
        });
        // 话题名称不能为空
        require(bytes(topics[nextTopicId].name).length > 0, "Topic name is empty");
        topicsByTokenAddress[_tokenAddress] = topics[nextTopicId];
        nextTopicId++;
    }

    // 查：根据id获取话题
    function getTopic(uint _topicId) public view returns (Topic memory) {
        return topics[_topicId];
    }

    // 查：根据tokenAddress获取话题
    function getTopicByTokenAddress(string memory _tokenAddress) public view returns (Topic memory) {
        return topicsByTokenAddress[_tokenAddress];
    }

    // 查：列出所有话题
    function listTopics() public view returns (Topic[] memory) {
        Topic[] memory topicsList = new Topic[](nextTopicId);
        for (uint i = 0; i < nextTopicId; i++) {
            topicsList[i] = topics[i];
        }
        return topicsList;
    }

    // 改：手动更新话题的token价格
    function updateTopicTokenPrice(uint _topicId, uint _tokenPrice) public {
        // 如果已经删除了，则name为空，不允许更新价格
        require(bytes(topics[_topicId].name).length > 0, "Topic not exist");
        topics[_topicId].tokenPrice = _tokenPrice;
    }
    
    // 改：自动更新话题的token价格 TODO chainlink-datafeed
    function updateTopicTokenPriceAuto(uint _topicId) public {
        // 如果已经删除了，则name为空，不允许更新价格
        require(bytes(topics[_topicId].name).length > 0, "Topic not exist");

        // chainlink-datafeed
        // 数据源地址不为0
        require(topics[_topicId].dataFeed != address(0), "Data feed not set");
        
        // TODO 后续改成用chainlink-datafeed获取价格
        topics[_topicId].tokenPrice = 0;
    }

    // 删：删除话题
    function deleteTopicToken(uint _topicId) public {
        delete topicsByTokenAddress[topics[_topicId].tokenAddress];
        delete topics[_topicId];        
    }
}