// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITimeSerLinkArray
 * @notice 时间序列双向链表接口，用于维护用户活动历史和全局活动历史
 */
interface ITimeSerLinkArray {
    // 时间节点结构
    struct TimeNode {
        uint prev;      // 前一个节点ID
        uint next;      // 下一个节点ID
        uint timestamp; // 时间戳
        bool exists;    // 是否存在
    }
    
    // 链表类型常量
    function COMMENT_LIST() external pure returns (uint);
    function LIKE_LIST() external pure returns (uint);
    
    // 查询函数
    function userHead(address user, uint listType) external view returns (uint);
    function userTail(address user, uint listType) external view returns (uint);
    function listSize(address user, uint listType) external view returns (uint);
    function timeNodes(address user, uint listType, uint nodeId) external view returns (TimeNode memory);
    function globalHead(uint listType) external view returns (uint);
    function globalTail(uint listType) external view returns (uint);
    function globalListSize(uint listType) external view returns (uint);
    function globalTimeNodes(uint listType, uint nodeId) external view returns (TimeNode memory);
    
    // 操作函数
    function addItem(address user, uint listType, uint nodeId, uint timestamp) external;
    
    // 查询功能
    function getRecentItems(address user, uint listType, uint n) external view returns (uint[] memory);
    function getRecentItemsPaginated(uint listType, uint startIndex, uint length) external view returns (uint[] memory);
    function exists(address user, uint listType, uint nodeId) external view returns (bool);
    function getListSize(address user, uint listType) external view returns (uint);
    function getGlobalListSize(uint listType) external view returns (uint);
} 