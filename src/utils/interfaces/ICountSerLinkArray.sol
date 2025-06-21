// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICountSerLinkArray
 * @notice 点赞数序列双向链表接口，维护评论按点赞数的全局排序
 */
interface ICountSerLinkArray {
    // 点赞数节点结构
    struct CountNode {
        uint prev;        // 前一个节点ID
        uint next;        // 下一个节点ID
        uint likeCount;   // 点赞数
        bool isDeleted;   // 是否已删除
        bool exists;      // 是否存在
    }
    
    // 查询函数
    function globalHead() external view returns (uint);
    function globalTail() external view returns (uint);
    function totalSize() external view returns (uint);
    function validSize() external view returns (uint);
    function countNodes(uint commentId) external view returns (CountNode memory);
    
    // 操作函数
    function addComment(uint commentId) external;
    function updateLikeCount(uint commentId, uint newLikeCount) external;
    function deleteComment(uint commentId) external;
    
    // 查询功能
    function getMostLikedComments(uint n) external view returns (uint[] memory);
    function getLeastLikedComments(uint n) external view returns (uint[] memory);
    function getMostLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory);
    function getValidCommentsCount() external view returns (uint);
} 