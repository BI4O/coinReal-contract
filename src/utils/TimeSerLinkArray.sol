// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TimeSerLinkArray
 * @dev 时间序列双向链表，用于维护用户活动历史和全局活动历史
 * 新项目总是插入到头部，保持时间倒序（最新的在前）
 */
contract TimeSerLinkArray {
    // 时间节点结构
    struct TimeNode {
        uint prev;      // 前一个节点ID
        uint next;      // 下一个节点ID
        uint timestamp; // 时间戳
        bool exists;    // 是否存在
    }
    
    // 链表类型常量
    uint public constant COMMENT_LIST = 1;
    uint public constant LIKE_LIST = 2;
    
    // 用户链表头尾指针 [user][listType] => nodeId
    mapping(address => mapping(uint => uint)) public userHead;
    mapping(address => mapping(uint => uint)) public userTail;
    
    // 链表大小 [user][listType] => size
    mapping(address => mapping(uint => uint)) public listSize;
    
    // 节点数据 [user][listType][nodeId] => TimeNode
    mapping(address => mapping(uint => mapping(uint => TimeNode))) public timeNodes;
    
    // 全局链表头尾指针 [listType] => nodeId
    mapping(uint => uint) public globalHead;
    mapping(uint => uint) public globalTail;
    
    // 全局链表大小 [listType] => size
    mapping(uint => uint) public globalListSize;
    
    // 全局节点数据 [listType][nodeId] => TimeNode
    mapping(uint => mapping(uint => TimeNode)) public globalTimeNodes;
    
    /**
     * @dev 添加项目到用户的时间序列链表头部
     * @param user 用户地址
     * @param listType 链表类型（COMMENT_LIST 或 LIKE_LIST）
     * @param nodeId 节点ID
     * @param timestamp 时间戳
     */
    function addItem(address user, uint listType, uint nodeId, uint timestamp) external {
        require(!timeNodes[user][listType][nodeId].exists, "Node already exists");
        
        // 添加到用户链表
        TimeNode storage newNode = timeNodes[user][listType][nodeId];
        newNode.timestamp = timestamp;
        newNode.exists = true;
        
        if (listSize[user][listType] == 0) {
            // 第一个节点
            userHead[user][listType] = nodeId;
            userTail[user][listType] = nodeId;
            newNode.prev = 0;
            newNode.next = 0;
        } else {
            // 插入到头部
            uint oldHead = userHead[user][listType];
            newNode.prev = 0;
            newNode.next = oldHead;
            timeNodes[user][listType][oldHead].prev = nodeId;
            userHead[user][listType] = nodeId;
        }
        
        listSize[user][listType]++;
        
        // 同时添加到全局链表
        _addToGlobalList(listType, nodeId, timestamp);
    }
    
    /**
     * @dev 添加项目到全局时间序列链表头部
     * @param listType 链表类型
     * @param nodeId 节点ID
     * @param timestamp 时间戳
     */
    function _addToGlobalList(uint listType, uint nodeId, uint timestamp) private {
        require(!globalTimeNodes[listType][nodeId].exists, "Global node already exists");
        
        TimeNode storage newNode = globalTimeNodes[listType][nodeId];
        newNode.timestamp = timestamp;
        newNode.exists = true;
        
        if (globalListSize[listType] == 0) {
            // 第一个节点
            globalHead[listType] = nodeId;
            globalTail[listType] = nodeId;
            newNode.prev = 0;
            newNode.next = 0;
        } else {
            // 插入到头部
            uint oldHead = globalHead[listType];
            newNode.prev = 0;
            newNode.next = oldHead;
            globalTimeNodes[listType][oldHead].prev = nodeId;
            globalHead[listType] = nodeId;
        }
        
        globalListSize[listType]++;
    }
    
    /**
     * @dev 获取用户最近的n个项目
     * @param user 用户地址
     * @param listType 链表类型
     * @param n 获取数量
     * @return 项目ID数组，按时间倒序
     */
    function getRecentItems(address user, uint listType, uint n) external view returns (uint[] memory) {
        uint size = listSize[user][listType];
        uint count = n < size ? n : size;
        
        if (count == 0) {
            return new uint[](0);
        }
        
        uint[] memory items = new uint[](count);
        uint current = userHead[user][listType];
        
        for (uint i = 0; i < count && current != 0; i++) {
            items[i] = current;
            current = timeNodes[user][listType][current].next;
        }
        
        return items;
    }
    
    /**
     * @dev 分页获取全局最近的项目
     * @param listType 链表类型
     * @param startIndex 起始索引
     * @param length 获取数量
     * @return 项目ID数组，按时间倒序
     */
    function getRecentItemsPaginated(uint listType, uint startIndex, uint length) external view returns (uint[] memory) {
        uint totalSize = globalListSize[listType];
        
        // 检查边界条件
        if (startIndex >= totalSize || length == 0) {
            return new uint[](0);
        }
        
        // 计算实际返回数量
        uint endIndex = startIndex + length;
        if (endIndex > totalSize) {
            endIndex = totalSize;
        }
        uint actualLength = endIndex - startIndex;
        
        uint[] memory items = new uint[](actualLength);
        uint current = globalHead[listType];
        
        // 跳到起始位置
        for (uint i = 0; i < startIndex && current != 0; i++) {
            current = globalTimeNodes[listType][current].next;
        }
        
        // 收集数据
        for (uint i = 0; i < actualLength && current != 0; i++) {
            items[i] = current;
            current = globalTimeNodes[listType][current].next;
        }
        
        return items;
    }
    
    /**
     * @dev 检查节点是否存在
     * @param user 用户地址
     * @param listType 链表类型
     * @param nodeId 节点ID
     * @return 是否存在
     */
    function exists(address user, uint listType, uint nodeId) external view returns (bool) {
        return timeNodes[user][listType][nodeId].exists;
    }
    
    /**
     * @dev 获取用户链表大小
     * @param user 用户地址
     * @param listType 链表类型
     * @return 链表大小
     */
    function getListSize(address user, uint listType) external view returns (uint) {
        return listSize[user][listType];
    }
    
    /**
     * @dev 获取全局链表大小
     * @param listType 链表类型
     * @return 链表大小
     */
    function getGlobalListSize(uint listType) external view returns (uint) {
        return globalListSize[listType];
    }
} 