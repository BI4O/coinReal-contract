// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CountSerLinkArray
 * @dev 点赞数序列双向链表，维护评论按点赞数的全局排序
 * 支持从两端遍历：头部是最多点赞，尾部是最少点赞
 * 优化版本：使用有序插入，避免全量重建和排序
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
        
        totalSize++;
        validSize++;
        
        // 直接插入到链表尾部（0点赞应该在最后）
        _insertAtTail(commentId);
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
        
        node.likeCount = newLikeCount;
        
        // 从当前位置移除节点
        _removeFromList(commentId);
        
        // 重新插入到正确位置
        _insertInOrder(commentId);
    }
    
    /**
     * @dev 标记评论为已删除
     * @param commentId 评论ID
     */
    function deleteComment(uint commentId) external {
        require(countNodes[commentId].exists, "Comment does not exist");
        require(!countNodes[commentId].isDeleted, "Comment already deleted");
        
        countNodes[commentId].isDeleted = true;
        
        // 从链表中移除
        _removeFromList(commentId);
        
        validSize--;
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
     * @dev 插入节点到链表尾部
     * @param commentId 评论ID
     */
    function _insertAtTail(uint commentId) private {
        CountNode storage newNode = countNodes[commentId];
        
        if (validSize == 1) {
            // 第一个节点
            globalHead = commentId;
            globalTail = commentId;
            newNode.prev = NULL_NODE;
            newNode.next = NULL_NODE;
        } else {
            // 插入到尾部
            CountNode storage oldTail = countNodes[globalTail];
            oldTail.next = commentId;
            newNode.prev = globalTail;
            newNode.next = NULL_NODE;
            globalTail = commentId;
        }
    }
    
    /**
     * @dev 按点赞数有序插入节点
     * @param commentId 评论ID
     */
    function _insertInOrder(uint commentId) private {
        CountNode storage newNode = countNodes[commentId];
        uint newLikeCount = newNode.likeCount;
        
        if (validSize == 0) {
            // 空链表
            globalHead = commentId;
            globalTail = commentId;
            newNode.prev = NULL_NODE;
            newNode.next = NULL_NODE;
            return;
        }
        
        // 从头部开始查找插入位置
        uint current = globalHead;
        
        // 如果新节点点赞数最多，插入到头部
        if (newLikeCount >= countNodes[current].likeCount) {
            newNode.next = globalHead;
            newNode.prev = NULL_NODE;
            countNodes[globalHead].prev = commentId;
            globalHead = commentId;
            return;
        }
        
        // 查找插入位置
        while (current != NULL_NODE) {
            CountNode storage currentNode = countNodes[current];
            
            if (newLikeCount >= currentNode.likeCount) {
                // 插入到current之前
                newNode.next = current;
                newNode.prev = currentNode.prev;
                
                if (currentNode.prev != NULL_NODE) {
                    countNodes[currentNode.prev].next = commentId;
                } else {
                    globalHead = commentId;
                }
                currentNode.prev = commentId;
                return;
            }
            
            current = currentNode.next;
        }
        
        // 插入到尾部
        CountNode storage oldTail = countNodes[globalTail];
        oldTail.next = commentId;
        newNode.prev = globalTail;
        newNode.next = NULL_NODE;
        globalTail = commentId;
    }
    
    /**
     * @dev 从链表中移除节点
     * @param commentId 评论ID
     */
    function _removeFromList(uint commentId) private {
        CountNode storage node = countNodes[commentId];
        
        // 更新前一个节点的next指针
        if (node.prev != NULL_NODE) {
            countNodes[node.prev].next = node.next;
        } else {
            // 这是头节点
            globalHead = node.next;
        }
        
        // 更新后一个节点的prev指针
        if (node.next != NULL_NODE) {
            countNodes[node.next].prev = node.prev;
        } else {
            // 这是尾节点
            globalTail = node.prev;
        }
        
        // 如果删除后链表为空，重置头尾指针
        if (validSize == 1) {
            globalHead = NULL_NODE;
            globalTail = NULL_NODE;
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
        
        while (current != NULL_NODE && index < count) {
            result[index] = current;
            index++;
            current = countNodes[current].next;
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
        
        // 跳过startIndex个评论
        while (current != NULL_NODE && validIndex < startIndex) {
            validIndex++;
            current = countNodes[current].next;
        }
        
        // 收集length个评论
        uint remaining = validSize - startIndex;
        uint count = length < remaining ? length : remaining;
        uint[] memory result = new uint[](count);
        uint index = 0;
        
        while (current != NULL_NODE && index < count) {
            result[index] = current;
            index++;
            current = countNodes[current].next;
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
        
        // 跳过startIndex个评论
        while (current != NULL_NODE && validIndex < startIndex) {
            validIndex++;
            current = countNodes[current].prev;
        }
        
        // 收集length个评论
        uint remaining = validSize - startIndex;
        uint count = length < remaining ? length : remaining;
        uint[] memory result = new uint[](count);
        uint index = 0;
        
        while (current != NULL_NODE && index < count) {
            result[index] = current;
            index++;
            current = countNodes[current].prev;
        }
        
        return result;
    }
} 