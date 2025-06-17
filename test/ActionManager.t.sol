// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {USDC} from "../src/token/USDC.sol";

contract ActionManagerTest is Test {
    UserManager userManager;
    TopicManager topicManager;
    ActionManager actionManager;
    USDC usdc;
    address user = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        usdc = new USDC();
        userManager = new UserManager();
        topicManager = new TopicManager(address(usdc));
        actionManager = new ActionManager(address(topicManager), address(userManager), 10 * 1e18, 5 * 1e18);
        userManager.registerUser(user, "Alice", "bio", "alice@example.com");
        userManager.registerUser(user2, "Bob", "bio", "bob@example.com");
        topicManager.registerTopic("BTC", "desc", "0xBTC", 1000);
    }

    function test_ActionManagerAddComment() public {
        (bool ok, uint id) = actionManager.addComment(0, user, "hello");
        assertTrue(ok);
        assertEq(actionManager.getComment(id).content, "hello");
    }

    function test_ActionManagerAddLike() public {
        actionManager.addComment(0, user, "hello");
        (bool ok, uint id) = actionManager.addLike(0, 0, user2);
        assertTrue(ok);
        assertEq(actionManager.getLike(id).commentId, 0);
    }

    function test_ActionManagerAddTags() public {
        (, uint id) = actionManager.addComment(0, user, "hello");
        string[] memory tags = new string[](1);
        tags[0] = "tag1";
        actionManager.addTags(id, tags);
        assertEq(actionManager.getCommentTags(id)[0], "tag1");
    }

    function test_ActionManagerDeleteComment() public {
        actionManager.addComment(0, user, "hello");
        vm.prank(user);
        actionManager.deleteComment(0);
        assertTrue(actionManager.getComment(0).isDelete);
    }

    function test_ActionManagerDoubleLike() public {
        actionManager.addComment(0, user, "hello");
        actionManager.addLike(0, 0, user2);
        vm.expectRevert();
        actionManager.addLike(0, 0, user2);
    }

    function test_GetRecentCommentsByUserAddress() public {
        // 用户发表3个评论
        actionManager.addComment(0, user, "comment1");
        actionManager.addComment(0, user, "comment2");
        actionManager.addComment(0, user, "comment3");
        
        // 获取最近2个评论
        uint[] memory recentComments = actionManager.getRecentCommentsByUserAddress(user, 2);
        
        // 应该返回最新的2个评论，按时间倒序
        assertEq(recentComments.length, 2);
        assertEq(recentComments[0], 2); // 最新的评论ID
        assertEq(recentComments[1], 1); // 第二新的评论ID
    }

    function test_GetRecentCommentsByUserAddress_EmptyCase() public {
        // 用户没有评论的情况
        uint[] memory recentComments = actionManager.getRecentCommentsByUserAddress(user, 5);
        assertEq(recentComments.length, 0);
    }

    function test_GetRecentCommentsByUserAddress_RequestMoreThanAvailable() public {
        // 用户只有1个评论，但请求5个
        actionManager.addComment(0, user, "only comment");
        
        uint[] memory recentComments = actionManager.getRecentCommentsByUserAddress(user, 5);
        
        assertEq(recentComments.length, 1);
        assertEq(recentComments[0], 0);
    }

    function test_GetRecentLikesByUserAddress() public {
        // 先创建一些评论供点赞
        actionManager.addComment(0, user, "comment1");
        actionManager.addComment(0, user, "comment2");
        actionManager.addComment(0, user, "comment3");
        
        // user2点赞这些评论
        actionManager.addLike(0, 0, user2);
        actionManager.addLike(0, 1, user2);
        actionManager.addLike(0, 2, user2);
        
        // 获取user2最近2个点赞
        uint[] memory recentLikes = actionManager.getRecentLikesByUserAddress(user2, 2);
        
        // 应该返回最新的2个点赞，按时间倒序
        assertEq(recentLikes.length, 2);
        assertEq(recentLikes[0], 2); // 最新的点赞ID
        assertEq(recentLikes[1], 1); // 第二新的点赞ID
    }

    function test_GetRecentLikesByUserAddress_EmptyCase() public {
        // 用户没有点赞的情况
        uint[] memory recentLikes = actionManager.getRecentLikesByUserAddress(user, 5);
        assertEq(recentLikes.length, 0);
    }

    function test_GetRecentLikesByUserAddress_RequestMoreThanAvailable() public {
        // 创建一个评论并点赞
        actionManager.addComment(0, user, "comment");
        actionManager.addLike(0, 0, user2);
        
        // user2只有1个点赞，但请求5个
        uint[] memory recentLikes = actionManager.getRecentLikesByUserAddress(user2, 5);
        
        assertEq(recentLikes.length, 1);
        assertEq(recentLikes[0], 0);
    }

    function test_MultipleUsersCommentsAndLikes() public {
        // user发表2个评论
        actionManager.addComment(0, user, "user comment1");
        actionManager.addComment(0, user, "user comment2");
        
        // user2发表1个评论
        actionManager.addComment(0, user2, "user2 comment1");
        
        // user2点赞user的评论
        actionManager.addLike(0, 0, user2);
        actionManager.addLike(0, 1, user2);
        
        // 验证user的评论列表
        uint[] memory userComments = actionManager.getRecentCommentsByUserAddress(user, 10);
        assertEq(userComments.length, 2);
        assertEq(userComments[0], 1); // 最新评论
        assertEq(userComments[1], 0); // 较早评论
        
        // 验证user2的评论列表
        uint[] memory user2Comments = actionManager.getRecentCommentsByUserAddress(user2, 10);
        assertEq(user2Comments.length, 1);
        assertEq(user2Comments[0], 2);
        
        // 验证user2的点赞列表
        uint[] memory user2Likes = actionManager.getRecentLikesByUserAddress(user2, 10);
        assertEq(user2Likes.length, 2);
        assertEq(user2Likes[0], 1); // 最新点赞
        assertEq(user2Likes[1], 0); // 较早点赞
        
        // 验证user没有点赞
        uint[] memory userLikes = actionManager.getRecentLikesByUserAddress(user, 10);
        assertEq(userLikes.length, 0);
    }

    function test_GetMostLikedComments() public {
        // 创建3个评论
        actionManager.addComment(0, user, "comment1");
        actionManager.addComment(0, user, "comment2");
        actionManager.addComment(0, user, "comment3");
        
        // user2给评论点赞，创建不同的点赞数
        // comment0: 3个点赞
        actionManager.addLike(0, 0, user2);
        address user3 = address(0x3);
        userManager.registerUser(user3, "Charlie", "bio", "charlie@example.com");
        actionManager.addLike(0, 0, user3);
        address user4 = address(0x4);
        userManager.registerUser(user4, "David", "bio", "david@example.com");
        actionManager.addLike(0, 0, user4);
        
        // comment1: 1个点赞
        actionManager.addLike(0, 1, user2);
        
        // comment2: 2个点赞
        actionManager.addLike(0, 2, user2);
        actionManager.addLike(0, 2, user3);
        
        // 获取最多点赞的2个评论
        uint[] memory mostLiked = actionManager.getMostLikedComments(2);
        
        assertEq(mostLiked.length, 2);
        assertEq(mostLiked[0], 0); // comment0有3个点赞，应该排第一
        assertEq(mostLiked[1], 2); // comment2有2个点赞，应该排第二
    }

    function test_GetLeastLikedComments() public {
        // 创建3个评论
        actionManager.addComment(0, user, "comment1");
        actionManager.addComment(0, user, "comment2");
        actionManager.addComment(0, user, "comment3");
        
        // user2给评论点赞，创建不同的点赞数
        // comment0: 3个点赞
        actionManager.addLike(0, 0, user2);
        address user3 = address(0x3);
        userManager.registerUser(user3, "Charlie", "bio", "charlie@example.com");
        actionManager.addLike(0, 0, user3);
        address user4 = address(0x4);
        userManager.registerUser(user4, "David", "bio", "david@example.com");
        actionManager.addLike(0, 0, user4);
        
        // comment1: 1个点赞
        actionManager.addLike(0, 1, user2);
        
        // comment2: 2个点赞
        actionManager.addLike(0, 2, user2);
        actionManager.addLike(0, 2, user3);
        
        // 获取最少点赞的2个评论
        uint[] memory leastLiked = actionManager.getLeastLikedComments(2);
        
        assertEq(leastLiked.length, 2);
        assertEq(leastLiked[0], 1); // comment1有1个点赞，应该排第一
        assertEq(leastLiked[1], 2); // comment2有2个点赞，应该排第二
    }

    function test_GetMostLikedComments_EmptyCase() public {
        // 没有评论的情况
        uint[] memory mostLiked = actionManager.getMostLikedComments(5);
        assertEq(mostLiked.length, 0);
    }

    function test_GetLeastLikedComments_EmptyCase() public {
        // 没有评论的情况
        uint[] memory leastLiked = actionManager.getLeastLikedComments(5);
        assertEq(leastLiked.length, 0);
    }

    function test_GetMostLikedComments_WithDeletedComments() public {
        // 创建2个评论
        actionManager.addComment(0, user, "comment1");
        actionManager.addComment(0, user, "comment2");
        
        // 给评论点赞
        actionManager.addLike(0, 0, user2);
        actionManager.addLike(0, 1, user2);
        
        // 删除第一个评论
        vm.prank(user);
        actionManager.deleteComment(0);
        
        // 获取最多点赞的评论，应该跳过已删除的评论
        uint[] memory mostLiked = actionManager.getMostLikedComments(5);
        
        assertEq(mostLiked.length, 1);
        assertEq(mostLiked[0], 1); // 只有comment1没被删除
    }

    function test_GetMostLikedCommentsPaginated() public {
        // 创建5个评论，设置不同的点赞数
        actionManager.addComment(0, user, "comment0"); // 0个点赞
        actionManager.addComment(0, user, "comment1"); // 1个点赞
        actionManager.addComment(0, user, "comment2"); // 2个点赞
        actionManager.addComment(0, user, "comment3"); // 3个点赞
        actionManager.addComment(0, user, "comment4"); // 4个点赞
        
        // 添加不同数量的点赞
        address user3 = address(0x3);
        address user4 = address(0x4);
        address user5 = address(0x5);
        userManager.registerUser(user3, "Charlie", "bio", "charlie@example.com");
        userManager.registerUser(user4, "David", "bio", "david@example.com");
        userManager.registerUser(user5, "Eve", "bio", "eve@example.com");
        
        // comment1: 1个点赞
        actionManager.addLike(0, 1, user2);
        
        // comment2: 2个点赞
        actionManager.addLike(0, 2, user2);
        actionManager.addLike(0, 2, user3);
        
        // comment3: 3个点赞
        actionManager.addLike(0, 3, user2);
        actionManager.addLike(0, 3, user3);
        actionManager.addLike(0, 3, user4);
        
        // comment4: 4个点赞
        actionManager.addLike(0, 4, user2);
        actionManager.addLike(0, 4, user3);
        actionManager.addLike(0, 4, user4);
        actionManager.addLike(0, 4, user5);
        
        // 测试分页：获取从索引0开始的2个最多点赞评论
        uint[] memory page1 = actionManager.getMostLikedCommentsPaginated(0, 2);
        assertEq(page1.length, 2);
        assertEq(page1[0], 4); // comment4有4个点赞，排第一
        assertEq(page1[1], 3); // comment3有3个点赞，排第二
        
        // 测试分页：获取从索引2开始的2个最多点赞评论
        uint[] memory page2 = actionManager.getMostLikedCommentsPaginated(2, 2);
        assertEq(page2.length, 2);
        assertEq(page2[0], 2); // comment2有2个点赞，排第三
        assertEq(page2[1], 1); // comment1有1个点赞，排第四
        
        // 测试分页：获取最后一页
        uint[] memory page3 = actionManager.getMostLikedCommentsPaginated(4, 2);
        assertEq(page3.length, 1);
        assertEq(page3[0], 0); // comment0有0个点赞，排最后
    }

    function test_GetLeastLikedCommentsPaginated() public {
        // 创建3个评论，设置不同的点赞数
        actionManager.addComment(0, user, "comment0"); // 0个点赞
        actionManager.addComment(0, user, "comment1"); // 1个点赞
        actionManager.addComment(0, user, "comment2"); // 2个点赞
        
        address user3 = address(0x3);
        userManager.registerUser(user3, "Charlie", "bio", "charlie@example.com");
        
        // comment1: 1个点赞
        actionManager.addLike(0, 1, user2);
        
        // comment2: 2个点赞
        actionManager.addLike(0, 2, user2);
        actionManager.addLike(0, 2, user3);
        
        // 测试分页：获取从索引0开始的2个最少点赞评论
        uint[] memory page1 = actionManager.getLeastLikedCommentsPaginated(0, 2);
        assertEq(page1.length, 2);
        assertEq(page1[0], 0); // comment0有0个点赞，排第一
        assertEq(page1[1], 1); // comment1有1个点赞，排第二
        
        // 测试分页：获取从索引1开始的2个最少点赞评论
        uint[] memory page2 = actionManager.getLeastLikedCommentsPaginated(1, 2);
        assertEq(page2.length, 2);
        assertEq(page2[0], 1); // comment1有1个点赞，排第二
        assertEq(page2[1], 2); // comment2有2个点赞，排第三
    }

    function test_GetValidCommentsCount() public {
        // 创建3个评论
        actionManager.addComment(0, user, "comment1");
        actionManager.addComment(0, user, "comment2");
        actionManager.addComment(0, user, "comment3");
        
        // 验证总数
        assertEq(actionManager.getValidCommentsCount(), 3);
        
        // 删除一个评论
        vm.prank(user);
        actionManager.deleteComment(1);
        
        // 验证删除后的总数
        assertEq(actionManager.getValidCommentsCount(), 2);
    }

    function test_PaginatedFunctions_EdgeCases() public {
        // 空数据情况
        uint[] memory empty1 = actionManager.getMostLikedCommentsPaginated(0, 5);
        assertEq(empty1.length, 0);
        
        uint[] memory empty2 = actionManager.getLeastLikedCommentsPaginated(0, 5);
        assertEq(empty2.length, 0);
        
        // 创建1个评论
        actionManager.addComment(0, user, "comment1");
        
        // 超出范围的startIndex
        uint[] memory outOfRange = actionManager.getMostLikedCommentsPaginated(5, 2);
        assertEq(outOfRange.length, 0);
        
        // 正常情况
        uint[] memory normal = actionManager.getMostLikedCommentsPaginated(0, 5);
        assertEq(normal.length, 1);
        assertEq(normal[0], 0);
    }
} 