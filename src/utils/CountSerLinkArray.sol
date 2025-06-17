// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CountSerLinkArray
 * @dev 点赞数序列双向链表，维护评论按点赞数的全局排序
 * 支持从两端遍历：头部是最多点赞，尾部是最少点赞
 */
contract CountSerLinkArray {
    // 链表结束标记
    uint private constant NULL_NODE = type(uint).max;
    
    // 点赞数节点结构
    struct CountNode {
        uint prev;        // 前一个节点ID
        uint next;        // 下一个节点ID
        uint likeCount;   // 点赞数
        bool isDeleted;   // 是否已删除
        bool exists;      // 是否存在
    }
    
    // 全局链表头尾指针
    uint public globalHead; // 最多点赞的评论ID
    uint public globalTail; // 最少点赞的评论ID
    
    // 链表大小（包括已删除的节点）
    uint public totalSize;
    
    // 有效节点数量（不包括已删除的节点）
    uint public validSize;
    
    // 节点数据 [commentId] => CountNode
    mapping(uint => CountNode) public countNodes;
    
    // 所有评论ID的数组，用于重建链表
    uint[] private allCommentIds;
    
    /**
     * @dev 添加新评论到链表尾部（0点赞）
     * @param commentId 评论ID
     */
    function addComment(uint commentId) external {
        require(!countNodes[commentId].exists, "Comment already exists");
        
        CountNode storage newNode = countNodes[commentId];
        newNode.likeCount = 0;
        newNode.isDeleted = false;
        newNode.exists = true;
        newNode.prev = NULL_NODE;
        newNode.next = NULL_NODE;
        
        // 添加到数组中
        allCommentIds.push(commentId);
        
        totalSize++;
        validSize++;
        
        // 重建链表
        _rebuildList();
    }
    
    /**
     * @dev 更新评论的点赞数，重新定位其在链表中的位置
     * @param commentId 评论ID
     * @param newLikeCount 新的点赞数
     */
    function updateLikeCount(uint commentId, uint newLikeCount) external {
        require(countNodes[commentId].exists, "Comment does not exist");
        require(!countNodes[commentId].isDeleted, "Comment is deleted");
        
        CountNode storage node = countNodes[commentId];
        
        // 如果点赞数没有变化，直接返回
        if (node.likeCount == newLikeCount) {
            return;
        }
        
        // 更新点赞数
        node.likeCount = newLikeCount;
        
        // 重建链表
        _rebuildList();
    }
    
    /**
     * @dev 标记评论为已删除
     * @param commentId 评论ID
     */
    function deleteComment(uint commentId) external {
        require(countNodes[commentId].exists, "Comment does not exist");
        require(!countNodes[commentId].isDeleted, "Comment already deleted");
        
        countNodes[commentId].isDeleted = true;
        
        // 重建链表以移除已删除的评论
        _rebuildList();
    }
    
    /**
     * @dev 获取最多点赞的n个评论（从头部开始）
     * @param n 获取数量
     * @return 评论ID数组，按点赞数降序
     */
    function getMostLikedComments(uint n) external view returns (uint[] memory) {
        return _getCommentsFromHead(n);
    }
    
    /**
     * @dev 获取最少点赞的n个评论（从尾部开始）
     * @param n 获取数量
     * @return 评论ID数组，按点赞数升序
     */
    function getLeastLikedComments(uint n) external view returns (uint[] memory) {
        return _getCommentsFromTail(n);
    }
    
    /**
     * @dev 分页获取最多点赞的评论
     * @param startIndex 起始索引
     * @param length 获取数量
     * @return 评论ID数组
     */
    function getMostLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory) {
        return _getCommentsFromHeadPaginated(startIndex, length);
    }
    
    /**
     * @dev 分页获取最少点赞的评论
     * @param startIndex 起始索引
     * @param length 获取数量
     * @return 评论ID数组
     */
    function getLeastLikedCommentsPaginated(uint startIndex, uint length) external view returns (uint[] memory) {
        return _getCommentsFromTailPaginated(startIndex, length);
    }
    
    /**
     * @dev 获取有效评论总数
     * @return 有效评论数量
     */
    function getValidCommentsCount() external view returns (uint) {
        return validSize;
    }
    
    /**
     * @dev 重建整个链表，按点赞数降序排列
     */
    function _rebuildList() private {
        if (allCommentIds.length == 0) {
            globalHead = 0;
            globalTail = 0;
            return;
        }
        
        // 创建临时数组存储有效的评论ID
        uint[] memory validIds = new uint[](allCommentIds.length);
        uint validCount = 0;
        
        // 过滤已删除的评论
        for (uint i = 0; i < allCommentIds.length; i++) {
            if (!countNodes[allCommentIds[i]].isDeleted) {
                validIds[validCount] = allCommentIds[i];
                validCount++;
            }
        }
        
        if (validCount == 0) {
            globalHead = NULL_NODE;
            globalTail = NULL_NODE;
            validSize = 0;
            return;
        }
        
        // 更新有效大小
        validSize = validCount;
        
        // 使用冒泡排序按点赞数降序排列
        for (uint i = 0; i < validCount - 1; i++) {
            for (uint j = 0; j < validCount - i - 1; j++) {
                if (countNodes[validIds[j]].likeCount < countNodes[validIds[j + 1]].likeCount) {
                    uint temp = validIds[j];
                    validIds[j] = validIds[j + 1];
                    validIds[j + 1] = temp;
                }
            }
        }
        
        // 重建链表指针
        for (uint i = 0; i < validCount; i++) {
            uint commentId = validIds[i];
            CountNode storage node = countNodes[commentId];
            
            if (i == 0) {
                // 第一个节点
                node.prev = NULL_NODE;
                globalHead = commentId;
            } else {
                node.prev = validIds[i - 1];
            }
            
            if (i == validCount - 1) {
                // 最后一个节点
                node.next = NULL_NODE;
                globalTail = commentId;
            } else {
                node.next = validIds[i + 1];
            }
        }
    }
    
    /**
     * @dev 从头部获取n个有效评论
     * @param n 获取数量
     * @return 评论ID数组
     */
    function _getCommentsFromHead(uint n) private view returns (uint[] memory) {
        if (n == 0 || validSize == 0) {
            return new uint[](0);
        }
        
        uint count = n < validSize ? n : validSize;
        uint[] memory result = new uint[](count);
        uint current = globalHead;
        uint index = 0;
        
        // 添加循环检测
        uint steps = 0;
        uint maxSteps = validSize + 1; // 最多应该走validSize步
        
        while (current != NULL_NODE && index < count && steps < maxSteps) {
            result[index] = current;
            index++;
            current = countNodes[current].next;
            steps++;
        }
        
        return result;
    }
    
    /**
     * @dev 从尾部获取n个有效评论
     * @param n 获取数量
     * @return 评论ID数组
     */
    function _getCommentsFromTail(uint n) private view returns (uint[] memory) {
        if (n == 0 || validSize == 0) {
            return new uint[](0);
        }
        
        uint count = n < validSize ? n : validSize;
        uint[] memory result = new uint[](count);
        uint current = globalTail;
        uint index = 0;
        
        while (current != NULL_NODE && index < count) {
            result[index] = current;
            index++;
            current = countNodes[current].prev;
        }
        
        return result;
    }
    
    /**
     * @dev 分页从头部获取评论
     * @param startIndex 起始索引
     * @param length 获取数量
     * @return 评论ID数组
     */
    function _getCommentsFromHeadPaginated(uint startIndex, uint length) private view returns (uint[] memory) {
        if (length == 0 || validSize == 0 || startIndex >= validSize) {
            return new uint[](0);
        }
        
        uint current = globalHead;
        uint validIndex = 0;
        
        // 跳过startIndex个有效评论
        while (current != NULL_NODE && validIndex < startIndex) {
            if (!countNodes[current].isDeleted) {
                validIndex++;
            }
            current = countNodes[current].next;
        }
        
        // 收集length个有效评论
        uint remaining = validSize - startIndex;
        uint count = length < remaining ? length : remaining;
        uint[] memory result = new uint[](count);
        uint index = 0;
        
        while (current != NULL_NODE && index < count) {
            if (!countNodes[current].isDeleted) {
                result[index] = current;
                index++;
            }
            current = countNodes[current].next;
        }
        
        // 调整数组大小
        if (index < count) {
            uint[] memory adjustedResult = new uint[](index);
            for (uint i = 0; i < index; i++) {
                adjustedResult[i] = result[i];
            }
            return adjustedResult;
        }
        
        return result;
    }
    
    /**
     * @dev 分页从尾部获取评论
     * @param startIndex 起始索引
     * @param length 获取数量
     * @return 评论ID数组
     */
    function _getCommentsFromTailPaginated(uint startIndex, uint length) private view returns (uint[] memory) {
        if (length == 0 || validSize == 0 || startIndex >= validSize) {
            return new uint[](0);
        }
        
        uint current = globalTail;
        uint validIndex = 0;
        
        // 跳过startIndex个有效评论
        while (current != NULL_NODE && validIndex < startIndex) {
            if (!countNodes[current].isDeleted) {
                validIndex++;
            }
            current = countNodes[current].prev;
        }
        
        // 收集length个有效评论
        uint remaining = validSize - startIndex;
        uint count = length < remaining ? length : remaining;
        uint[] memory result = new uint[](count);
        uint index = 0;
        
        while (current != NULL_NODE && index < count) {
            if (!countNodes[current].isDeleted) {
                result[index] = current;
                index++;
            }
            current = countNodes[current].prev;
        }
        
        // 调整数组大小
        if (index < count) {
            uint[] memory adjustedResult = new uint[](index);
            for (uint i = 0; i < index; i++) {
                adjustedResult[i] = result[i];
            }
            return adjustedResult;
        }
        
        return result;
    }
} 