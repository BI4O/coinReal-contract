// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import {CountSerLinkArray} from "../src/utils/CountSerLinkArray.sol";
import {TimeSerLinkArray} from "../src/utils/TimeSerLinkArray.sol";

contract LinkArrayTest is Test {
    CountSerLinkArray countSerLinkArray;
    TimeSerLinkArray timeSerLinkArray;
    
    function setUp() public {
        countSerLinkArray = new CountSerLinkArray();
        timeSerLinkArray = new TimeSerLinkArray();
    }

    function test_CountSerLinkArray_BasicFunctionality() public {
        // 添加一些评论
        countSerLinkArray.addComment(1);
        countSerLinkArray.addComment(2);
        countSerLinkArray.addComment(3);
        
        // 验证计数
        assertEq(countSerLinkArray.getValidCommentsCount(), 3);
        
        // 更新点赞数
        countSerLinkArray.updateLikeCount(1, 5);
        countSerLinkArray.updateLikeCount(2, 3);
        countSerLinkArray.updateLikeCount(3, 1);
        
        // 获取最多点赞的评论
        uint[] memory mostLiked = countSerLinkArray.getMostLikedComments(2);
        assertEq(mostLiked.length, 2);
        assertEq(mostLiked[0], 1); // 5个点赞
        assertEq(mostLiked[1], 2); // 3个点赞
        
        // 获取最少点赞的评论
        uint[] memory leastLiked = countSerLinkArray.getLeastLikedComments(2);
        assertEq(leastLiked.length, 2);
        assertEq(leastLiked[0], 3); // 1个点赞
        assertEq(leastLiked[1], 2); // 3个点赞
    }

    function test_CountSerLinkArray_DeleteComment() public {
        // 添加评论
        countSerLinkArray.addComment(1);
        countSerLinkArray.addComment(2);
        
        assertEq(countSerLinkArray.getValidCommentsCount(), 2);
        
        // 删除评论
        countSerLinkArray.deleteComment(1);
        
        assertEq(countSerLinkArray.getValidCommentsCount(), 1);
        
        // 验证已删除的评论不会出现在结果中
        uint[] memory comments = countSerLinkArray.getMostLikedComments(5);
        assertEq(comments.length, 1);
        assertEq(comments[0], 2);
    }

    function test_TimeSerLinkArray_GlobalFunctionality() public {
        address user1 = address(0x1);
        address user2 = address(0x2);
        
        // 添加评论到全局链表
        timeSerLinkArray.addItem(user1, timeSerLinkArray.COMMENT_LIST(), 1, block.timestamp);
        timeSerLinkArray.addItem(user2, timeSerLinkArray.COMMENT_LIST(), 2, block.timestamp + 1);
        timeSerLinkArray.addItem(user1, timeSerLinkArray.COMMENT_LIST(), 3, block.timestamp + 2);
        
        // 验证全局计数
        assertEq(timeSerLinkArray.getGlobalListSize(timeSerLinkArray.COMMENT_LIST()), 3);
        
        // 获取全局最近评论
        uint[] memory recentComments = timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.COMMENT_LIST(), 0, 2);
        assertEq(recentComments.length, 2);
        assertEq(recentComments[0], 3); // 最新的
        assertEq(recentComments[1], 2); // 第二新的
        
        // 测试分页
        uint[] memory page2 = timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.COMMENT_LIST(), 1, 2);
        assertEq(page2.length, 2);
        assertEq(page2[0], 2); // 第二新的
        assertEq(page2[1], 1); // 最早的
    }

    function test_TimeSerLinkArray_LikeFunctionality() public {
        address user1 = address(0x1);
        address user2 = address(0x2);
        
        // 添加点赞到全局链表
        timeSerLinkArray.addItem(user1, timeSerLinkArray.LIKE_LIST(), 1, block.timestamp);
        timeSerLinkArray.addItem(user2, timeSerLinkArray.LIKE_LIST(), 2, block.timestamp + 1);
        
        // 验证全局计数
        assertEq(timeSerLinkArray.getGlobalListSize(timeSerLinkArray.LIKE_LIST()), 2);
        
        // 获取全局最近点赞
        uint[] memory recentLikes = timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.LIKE_LIST(), 0, 5);
        assertEq(recentLikes.length, 2);
        assertEq(recentLikes[0], 2); // 最新的
        assertEq(recentLikes[1], 1); // 最早的
    }

    function test_TimeSerLinkArray_EmptyAndEdgeCases() public {
        // 空链表情况
        uint[] memory empty = timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.COMMENT_LIST(), 0, 5);
        assertEq(empty.length, 0);
        
        // 超出范围的startIndex
        timeSerLinkArray.addItem(address(0x1), timeSerLinkArray.COMMENT_LIST(), 1, block.timestamp);
        uint[] memory outOfRange = timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.COMMENT_LIST(), 5, 2);
        assertEq(outOfRange.length, 0);
        
        // length为0的情况
        uint[] memory zeroLength = timeSerLinkArray.getRecentItemsPaginated(timeSerLinkArray.COMMENT_LIST(), 0, 0);
        assertEq(zeroLength.length, 0);
    }
} 