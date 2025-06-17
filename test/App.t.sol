// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import {App} from "../src/core/App.sol";
import {USDC} from "../src/token/USDC.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";

contract AppTest is Test {
    App app;
    USDC usdc;
    address user = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address admin = address(this);
    UserManager userManager;
    TopicManager topicManager;
    ActionManager actionManager;

    function setUp() public {
        usdc = new USDC();
        userManager = new UserManager();
        topicManager = new TopicManager(address(usdc));
        actionManager = new ActionManager(address(topicManager), address(userManager), 10 * 1e18, 5 * 1e18);
        app = new App(address(usdc), address(userManager), address(topicManager), address(actionManager));
        vm.prank(user);
        app.registerUser("Alice", "bio", "alice@example.com");
        vm.startPrank(admin);
        app.registerTopic("BTC", "desc", "0xBTC", 1000);
        app.registerCampaign(admin, 0, "BTC_Activity", "desc", address(0));
        vm.stopPrank();
    }

    function test_AppRegisterAndComment() public {
        vm.prank(user);
        app.comment(0, "hello");
        // 只要不revert即通过
    }

    function test_AppRegisterAndLike() public {
        vm.prank(user);
        app.comment(0, "hello");
        vm.prank(user);
        app.like(0, 0);
    }

    function test_AppCommentAndReward() public {
        vm.prank(user);
        app.comment(0, "hello");
        // 奖励逻辑可在ActionManagerTest中详细测
    }

    function test_AppLikeAndReward() public {
        vm.prank(user);
        app.comment(0, "hello");
        vm.prank(user);
        app.like(0, 0);
        // 奖励逻辑可在ActionManagerTest中详细测
    }

    function test_AppPermissionControl() public {
        address notRegistered = address(0x2);
        vm.prank(notRegistered);
        vm.expectRevert();
        app.comment(0, "fail");
    }

    function test_AttackDoubleRegister() public {
        // 在setUp()中已经注册了user，所以这里直接测试重复注册
        vm.prank(user);
        vm.expectRevert("User already registered");
        app.registerUser("Alice", "bio", "alice@example.com");
    }

    function test_AttackFakeTopic() public {
        vm.prank(user);
        vm.expectRevert();
        app.comment(99, "fail");
    }

    function test_AttackFakeUserComment() public {
        address notRegistered = address(0x2);
        vm.prank(notRegistered);
        vm.expectRevert();
        app.comment(0, "fail");
    }

    function test_AttackExceedCampaignLimit() public {
        vm.startPrank(admin);
        // setUp()中已经注册了1个campaign，现在再注册2个，总共3个达到限制
        app.registerCampaign(admin, 0, "A", "desc", address(0));
        app.registerCampaign(admin, 0, "B", "desc", address(0));
        // 尝试注册第4个，应该失败
        vm.expectRevert("Topic campaign limit reached");
        app.registerCampaign(admin, 0, "C", "desc", address(0));
        vm.stopPrank();
    }

    function test_AttackRewardAbuse() public {
        // 注册第二个用户
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "test comment");
        
        // 用户尝试多次点赞同一评论（应该失败）
        vm.prank(user2);
        app.like(0, 0);
        
        vm.prank(user2);
        vm.expectRevert();
        app.like(0, 0); // 重复点赞应该失败
    }

    // 测试新增的查询功能
    function test_AppGetUserRecentComments() public {
        // 用户发表3个评论
        vm.startPrank(user);
        app.comment(0, "comment1");
        app.comment(0, "comment2");
        app.comment(0, "comment3");
        vm.stopPrank();
        
        // 获取用户最近2个评论
        uint[] memory recentComments = app.getUserRecentComments(user, 2);
        assertEq(recentComments.length, 2);
        assertEq(recentComments[0], 2); // 最新的评论ID
        assertEq(recentComments[1], 1); // 第二新的评论ID
    }

    function test_AppGetUserRecentLikes() public {
        // 注册第二个用户
        address user2 = address(0x2);
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "comment1");
        vm.prank(user);
        app.comment(0, "comment2");
        
        // user2点赞这些评论
        vm.prank(user2);
        app.like(0, 0);
        vm.prank(user2);
        app.like(0, 1);
        
        // 获取user2最近的点赞
        uint[] memory recentLikes = app.getUserRecentLikes(user2, 2);
        assertEq(recentLikes.length, 2);
        assertEq(recentLikes[0], 1); // 最新的点赞ID
        assertEq(recentLikes[1], 0); // 第二新的点赞ID
    }

    function test_AppGetMostLikedComments() public {
        // 注册多个用户
        address user2 = address(0x2);
        address user3 = address(0x3);
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        vm.prank(user3);
        app.registerUser("Charlie", "bio", "charlie@example.com");
        
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "comment1");
        vm.prank(user);
        app.comment(0, "comment2");
        
        // 给评论不同数量的点赞
        // comment0: 2个点赞
        vm.prank(user2);
        app.like(0, 0);
        vm.prank(user3);
        app.like(0, 0);
        
        // comment1: 1个点赞
        vm.prank(user2);
        app.like(0, 1);
        
        // 获取最多点赞的评论
        uint[] memory mostLiked = app.getMostLikedComments(2);
        assertEq(mostLiked.length, 2);
        assertEq(mostLiked[0], 0); // comment0有2个点赞，排第一
        assertEq(mostLiked[1], 1); // comment1有1个点赞，排第二
    }

    function test_AppGetMostLikedCommentsPaginated() public {
        // 注册第二个用户
        address user2 = address(0x2);
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // 用户发表3个评论
        vm.startPrank(user);
        app.comment(0, "comment1");
        app.comment(0, "comment2");
        app.comment(0, "comment3");
        vm.stopPrank();
        
        // 给评论不同数量的点赞
        vm.prank(user2);
        app.like(0, 2); // comment2: 1个点赞
        
        // 测试分页查询
        uint[] memory page1 = app.getMostLikedCommentsPaginated(0, 2);
        assertEq(page1.length, 2);
        assertEq(page1[0], 2); // comment2有1个点赞，排第一
        
        uint[] memory page2 = app.getMostLikedCommentsPaginated(1, 2);
        assertEq(page2.length, 2);
        // 后面两个评论都是0个点赞
    }

    function test_AppGetValidCommentsCount() public {
        // 用户发表2个评论
        vm.prank(user);
        app.comment(0, "comment1");
        vm.prank(user);
        app.comment(0, "comment2");
        
        // 验证评论总数
        assertEq(app.getValidCommentsCount(), 2);
        
        // 删除一个评论
        vm.prank(user);
        app.deleteComment(0);
        
        // 验证删除后的总数
        assertEq(app.getValidCommentsCount(), 1);
    }

    function test_AppGetCommentDetails() public {
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "hello world");
        
        // 获取评论详情
        ActionManager.Comment memory commentDetail = app.getComment(0);
        assertEq(commentDetail.user, user);
        assertEq(commentDetail.content, "hello world");
        assertEq(commentDetail.topicId, 0);
        assertEq(commentDetail.likeCount, 0);
        assertEq(commentDetail.isDelete, false);
    }

    function test_AppAddCommentTags() public {
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "hello world");
        
        // 管理员添加标签
        string[] memory tags = new string[](2);
        tags[0] = "tech";
        tags[1] = "crypto";
        
        vm.prank(admin);
        app.addCommentTags(0, tags);
        
        // 验证标签
        string[] memory retrievedTags = app.getCommentTags(0);
        assertEq(retrievedTags.length, 2);
        assertEq(retrievedTags[0], "tech");
        assertEq(retrievedTags[1], "crypto");
    }

    function test_AppDeleteComment() public {
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "hello world");
        
        // 验证评论存在且未删除
        ActionManager.Comment memory commentBefore = app.getComment(0);
        assertEq(commentBefore.isDelete, false);
        
        // 用户删除自己的评论
        vm.prank(user);
        app.deleteComment(0);
        
        // 验证评论已删除
        ActionManager.Comment memory commentAfter = app.getComment(0);
        assertEq(commentAfter.isDelete, true);
    }

    function test_AppPermissionControlForTags() public {
        // 用户发表评论
        vm.prank(user);
        app.comment(0, "hello world");
        
        // 非管理员尝试添加标签应该失败
        string[] memory tags = new string[](1);
        tags[0] = "test";
        
        vm.prank(user);
        vm.expectRevert("Only admin can call this function");
        app.addCommentTags(0, tags);
    }

    function test_AppPermissionControlForDeleteComment() public {
        // 注册第二个用户
        address user2 = address(0x2);
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // user发表评论
        vm.prank(user);
        app.comment(0, "hello world");
        
        // user2尝试删除user的评论应该失败
        vm.prank(user2);
        vm.expectRevert("You are not the author of this comment");
        app.deleteComment(0);
    }

    function test_AppGetRecentCommentsPaginated() public {
        // 注册第二个用户
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // 不同用户发表评论
        vm.prank(user);
        app.comment(0, "comment1");
        vm.prank(user2);
        app.comment(0, "comment2");
        vm.prank(user);
        app.comment(0, "comment3");
        
        // 测试分页功能
        uint[] memory page1 = app.getRecentCommentsPaginated(0, 2);
        assertEq(page1.length, 2);
        assertEq(page1[0], 2); // 最新评论
        assertEq(page1[1], 1); // 第二新评论
        
        uint[] memory page2 = app.getRecentCommentsPaginated(1, 2);
        assertEq(page2.length, 2);
        assertEq(page2[0], 1); // 第二新评论
        assertEq(page2[1], 0); // 最早评论
    }

    function test_AppGetRecentLikesPaginated() public {
        // 注册其他用户
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        vm.prank(user3);
        app.registerUser("Charlie", "bio", "charlie@example.com");
        
        // 创建评论
        vm.prank(user);
        app.comment(0, "comment1");
        vm.prank(user);
        app.comment(0, "comment2");
        
        // 不同用户点赞
        vm.prank(user2);
        app.like(0, 0);
        vm.prank(user3);
        app.like(0, 1);
        vm.prank(user2);
        app.like(0, 1);
        
        // 测试分页功能
        uint[] memory page1 = app.getRecentLikesPaginated(0, 2);
        assertEq(page1.length, 2);
        assertEq(page1[0], 2); // 最新点赞
        assertEq(page1[1], 1); // 第二新点赞
        
        uint[] memory page2 = app.getRecentLikesPaginated(2, 2);
        assertEq(page2.length, 1);
        assertEq(page2[0], 0); // 最早点赞
    }

    function test_AppGlobalCountFunctions() public {
        // 初始状态
        assertEq(app.getGlobalCommentsCount(), 0);
        assertEq(app.getGlobalLikesCount(), 0);
        
        // 注册第二个用户
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // 创建评论
        vm.prank(user);
        app.comment(0, "comment1");
        vm.prank(user2);
        app.comment(0, "comment2");
        
        assertEq(app.getGlobalCommentsCount(), 2);
        assertEq(app.getGlobalLikesCount(), 0);
        
        // 创建点赞
        vm.prank(user2);
        app.like(0, 0);
        vm.prank(user);
        app.like(0, 1);
        
        assertEq(app.getGlobalCommentsCount(), 2);
        assertEq(app.getGlobalLikesCount(), 2);
    }

    function test_AppRecentPaginatedFunctions_EmptyCase() public {
        // 空数据情况
        uint[] memory emptyComments = app.getRecentCommentsPaginated(0, 5);
        assertEq(emptyComments.length, 0);
        
        uint[] memory emptyLikes = app.getRecentLikesPaginated(0, 5);
        assertEq(emptyLikes.length, 0);
        
        // 创建一个评论
        vm.prank(user);
        app.comment(0, "comment1");
        
        // 超出范围的startIndex
        uint[] memory outOfRange = app.getRecentCommentsPaginated(5, 2);
        assertEq(outOfRange.length, 0);
    }

    function test_AppRecentPaginatedFunctions_Integration() public {
        // 注册第二个用户
        vm.prank(user2);
        app.registerUser("Bob", "bio", "bob@example.com");
        
        // 创建混合的评论和点赞
        vm.prank(user);
        app.comment(0, "user comment1");
        vm.prank(user2);
        app.comment(0, "user2 comment1");
        vm.prank(user);
        app.comment(0, "user comment2");
        
        vm.prank(user2);
        app.like(0, 0);
        vm.prank(user);
        app.like(0, 1);
        vm.prank(user2);
        app.like(0, 2);
        
        // 验证全局计数
        assertEq(app.getGlobalCommentsCount(), 3);
        assertEq(app.getGlobalLikesCount(), 3);
        
        // 验证全局评论分页
        uint[] memory allComments = app.getRecentCommentsPaginated(0, 10);
        assertEq(allComments.length, 3);
        assertEq(allComments[0], 2); // 最新评论
        assertEq(allComments[1], 1);
        assertEq(allComments[2], 0); // 最早评论
        
        // 验证全局点赞分页
        uint[] memory allLikes = app.getRecentLikesPaginated(0, 10);
        assertEq(allLikes.length, 3);
        assertEq(allLikes[0], 2); // 最新点赞
        assertEq(allLikes[1], 1);
        assertEq(allLikes[2], 0); // 最早点赞
        
        // 验证分页功能
        uint[] memory partialComments = app.getRecentCommentsPaginated(1, 1);
        assertEq(partialComments.length, 1);
        assertEq(partialComments[0], 1);
        
        uint[] memory partialLikes = app.getRecentLikesPaginated(1, 1);
        assertEq(partialLikes.length, 1);
        assertEq(partialLikes[0], 1);
    }
} 