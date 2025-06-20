// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import {App} from "../src/core/App.sol";
import {USDC} from "../src/token/USDC.sol";
import {ProjectToken} from "../src/token/ProjectToken.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {CampaignToken} from "../src/token/Campaign.sol";
import {MockVRF} from "../src/chainlink/MockVRF.sol";

contract RewardTest is Test {
    App public app; 
    USDC public usdc;
    ProjectToken public projectToken;
    UserManager public userManager;
    TopicManager public topicManager;
    ActionManager public actionManager;
    MockVRF public mockVRF;
    
    address admin = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    
    uint commentRewardAmount = 10 * 1e18; // 10 tokens
    uint likeRewardAmount = 5 * 1e18;     // 5 tokens
    uint commentRewardExtraAmount;         // 点赞奖励的一半
    
    uint topicId;
    uint campaignId;
    uint commentId;
    
    function setUp() public {
        // 部署基础合约
        usdc = new USDC();
        projectToken = new ProjectToken();
        mockVRF = new MockVRF();
        
        // 部署管理合约
        userManager = new UserManager();
        topicManager = new TopicManager(
            address(usdc),
            5,  // 5% 平台费
            10, // 10% 质量评论者费
            5,  // 5% 点赞抽奖费
            2   // top 2 评论者
        );
        actionManager = new ActionManager(
            address(topicManager), 
            address(userManager), 
            commentRewardAmount, 
            likeRewardAmount,
            address(mockVRF),
            address(0), // commentTagFunctions address - 测试中使用零地址
            5044        // functionsSubscriptionId
        );
        
        // 部署App合约
        app = new App(
            address(usdc), 
            address(userManager), 
            address(topicManager), 
            address(actionManager),
            address(mockVRF)
        );
        
        // 设置各合约的owner为App
        userManager.setOwner(address(app));
        topicManager.setOwner(address(app));
        actionManager.setOwner(address(app));
        
        // 在转移owner后设置ActionManager引用
        app.setActionManager();
        
        // 记录点赞额外奖励金额
        commentRewardExtraAmount = likeRewardAmount / 2;
        
        // 注册用户
        vm.startPrank(user1);
        app.registerUser("User1", "bio1", "user1@example.com");
        vm.stopPrank();
        
        vm.startPrank(user2);
        app.registerUser("User2", "bio2", "user2@example.com");
        vm.stopPrank();
        
        vm.startPrank(user3);
        app.registerUser("User3", "bio3", "user3@example.com");
        vm.stopPrank();
        
        // 注册话题
        topicId = 0;
        app.registerTopic("BTC", "Bitcoin topic", "0xBTC", 1000);
        
        // 注册活动
        campaignId = 0;
        app.registerCampaign(admin, topicId, "BTC Campaign", "Bitcoin campaign description", address(projectToken));
        
        // 为项目代币铸造一些代币
        projectToken.deployerMint(1000000 * 1e18);
        
        // 为用户铸造一些USDC
        // 由于USDC只能由deployer为自己铸造，所以先铸造给admin，然后转给用户
        usdc.deployerMint(13000 * 1e6); // 为admin和所有用户铸造足够的USDC
        
        // 转账给用户
        usdc.transfer(user1, 1000 * 1e6);
        usdc.transfer(user2, 1000 * 1e6);
        usdc.transfer(user3, 1000 * 1e6);
        
        // 为用户铸造一些项目代币
        projectToken.transfer(user1, 1000 * 1e18);
        projectToken.transfer(user2, 1000 * 1e18);
        projectToken.transfer(user3, 1000 * 1e18);
    }
    
    // 测试评论奖励
    function test_CommentReward() public {
        // 先注资活动
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 获取活动代币地址
        address campaignTokenAddr = topicManager.getCampaignToken(campaignId);
        CampaignToken campaignToken = CampaignToken(campaignTokenAddr);
        
        // 用户1发表评论前的代币余额
        uint balanceBefore = campaignToken.balanceOf(user1);
        
        // 用户1发表评论
        vm.prank(user1);
        app.comment(topicId, "This is a test comment");
        
        // 验证用户1获得了评论奖励
        uint balanceAfter = campaignToken.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, commentRewardAmount);
    }
    
    // 测试点赞奖励
    function test_LikeReward() public {
        // 先注资活动
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 获取活动代币地址
        address campaignTokenAddr = topicManager.getCampaignToken(campaignId);
        CampaignToken campaignToken = CampaignToken(campaignTokenAddr);
        
        // 用户1发表评论
        vm.prank(user1);
        app.comment(topicId, "This is a test comment");
        
        // 记录用户2点赞前的代币余额
        uint user2BalanceBefore = campaignToken.balanceOf(user2);
        // 记录用户1点赞前的代币余额（用于验证额外奖励）
        uint user1BalanceBefore = campaignToken.balanceOf(user1);
        
        // 用户2点赞用户1的评论
        vm.prank(user2);
        app.like(topicId, 0); // 第一条评论的ID是0
        
        // 验证用户2获得了点赞奖励
        uint user2BalanceAfter = campaignToken.balanceOf(user2);
        assertEq(user2BalanceAfter - user2BalanceBefore, likeRewardAmount);
        
        // 验证用户1获得了额外奖励
        uint user1BalanceAfter = campaignToken.balanceOf(user1);
        assertEq(user1BalanceAfter - user1BalanceBefore, commentRewardExtraAmount);
    }
    
    // 测试删除评论时的代币销毁
    function test_DeleteCommentBurnToken() public {
        // 先注资活动
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 获取活动代币地址
        address campaignTokenAddr = topicManager.getCampaignToken(campaignId);
        CampaignToken campaignToken = CampaignToken(campaignTokenAddr);
        
        // 用户1发表评论
        vm.prank(user1);
        app.comment(topicId, "This is a test comment");
        
        // 记录用户1删除评论前的代币余额
        uint balanceBefore = campaignToken.balanceOf(user1);
        
        // 用户1删除自己的评论
        vm.prank(user1);
        actionManager.deleteComment(0); // 第一条评论的ID是0
        
        // 验证用户1的代币被销毁
        uint balanceAfter = campaignToken.balanceOf(user1);
        assertEq(balanceBefore - balanceAfter, commentRewardAmount);
    }
    
    // 移除重复测试 - 多点赞奖励在test_LikeReward中已覆盖
    
    // 测试活动结束后的奖励分配
    function test_CampaignEndRewardDistribution() public {
        // 先注资活动 - USDC
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 项目方代币注资
        projectToken.approve(address(app), 1000 * 1e18);
        app.fundCampaignWithProjectToken(campaignId, 1000 * 1e18);
        
        // 启动活动 - 设置较短的活动时间以便测试
        app.startCampaign(campaignId, block.timestamp + 2 days);
        
        // 获取活动代币地址
        address campaignTokenAddr = topicManager.getCampaignToken(campaignId);
        CampaignToken campaignToken = CampaignToken(campaignTokenAddr);
        
        // 用户1发表评论
        vm.prank(user1);
        app.comment(topicId, "Comment 1");
        
        // 用户2发表评论
        vm.prank(user2);
        app.comment(topicId, "Comment 2");
        
        // 用户互相点赞
        vm.prank(user1);
        app.like(topicId, 1); // 用户1点赞用户2的评论
        
        vm.prank(user2);
        app.like(topicId, 0); // 用户2点赞用户1的评论
        
        // 记录用户1和用户2的USDC和项目代币余额
        uint user1UsdcBefore = usdc.balanceOf(user1);
        uint user1PtokenBefore = projectToken.balanceOf(user1);
        uint user2UsdcBefore = usdc.balanceOf(user2);
        uint user2PtokenBefore = projectToken.balanceOf(user2);
        
        // 快进时间到活动结束
        vm.warp(block.timestamp + 3 days);
        
        // 结束活动
        app.endCampaign(campaignId);
        
        // 用户1领取奖励
        vm.prank(user1);
        campaignToken.claim();
        
        // 用户2领取奖励
        vm.prank(user2);
        campaignToken.claim();
        
        // 验证用户1获得了USDC和项目代币奖励
        uint user1UsdcAfter = usdc.balanceOf(user1);
        uint user1PtokenAfter = projectToken.balanceOf(user1);
        assertTrue(user1UsdcAfter > user1UsdcBefore, "User1 should receive USDC reward");
        assertTrue(user1PtokenAfter > user1PtokenBefore, "User1 should receive project token reward");
        
        // 验证用户2获得了USDC和项目代币奖励
        uint user2UsdcAfter = usdc.balanceOf(user2);
        uint user2PtokenAfter = projectToken.balanceOf(user2);
        assertTrue(user2UsdcAfter > user2UsdcBefore, "User2 should receive USDC reward");
        assertTrue(user2PtokenAfter > user2PtokenBefore, "User2 should receive project token reward");
    }
    
    // 移除重复测试 - 基础奖励机制已在其他测试中验证
    
    // 测试活动奖励不足时的自动结束
    function test_CampaignAutoEndOnLowJackpot() public {
        // 注资活动 - 混合注资USDC和项目代币
        usdc.approve(address(app), 500 * 1e6); // 500 USDC
        app.fundCampaignWithUSDC(campaignId, 500 * 1e6);
        
        // 注资项目代币，使总价值刚好超过最低要求
        projectToken.approve(address(app), 600 * 1e18); // 600个项目代币，价值600 USDC
        app.fundCampaignWithProjectToken(campaignId, 600 * 1e18);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 获取活动信息
        (, , , , , , bool isActive, , , , , , ) = topicManager.campaignInfos(campaignId);
        assertTrue(isActive, "Campaign should be active after start");
        
        // 模拟项目代币价格下跌
        projectToken.setPrice(1e5); // 价格降为原来的1/10，现在项目代币只值60 USDC
        
        // 尝试结束活动
        app.endCampaign(campaignId);
        
        // 验证活动已自动结束
        (, , , , , , bool isActiveAfter, , , , , , ) = topicManager.campaignInfos(campaignId);
        assertFalse(isActiveAfter, "Campaign should be inactive after price drop");
    }
    
    // 测试费用分配功能
    function test_FeeAllocation() public {
        uint fundAmount = 1000 * 1e6; // 1000 USDC
        
        // 预期的费用分配
        uint expectedPlatformFee = fundAmount * 5 / 100;      // 5% = 50 USDC
        uint expectedQualityFee = fundAmount * 10 / 100;      // 10% = 100 USDC  
        uint expectedLotteryFee = fundAmount * 5 / 100;       // 5% = 50 USDC
        uint expectedCampaignAmount = fundAmount - expectedPlatformFee - expectedQualityFee - expectedLotteryFee; // 800 USDC
        
        // 注资活动
        usdc.approve(address(app), fundAmount);
        app.fundCampaignWithUSDC(campaignId, fundAmount);
        
        // 验证费用池分配
        assertEq(actionManager.platformFeePool(campaignId), expectedPlatformFee, "Platform fee pool incorrect");
        assertEq(actionManager.qualityCommenterFeePool(campaignId), expectedQualityFee, "Quality commenter fee pool incorrect");
        assertEq(actionManager.lotteryForLikerFeePool(campaignId), expectedLotteryFee, "Lottery fee pool incorrect");
        
        // 验证CampaignToken收到的金额
        address campaignTokenAddr = topicManager.getCampaignToken(campaignId);
        assertEq(usdc.balanceOf(campaignTokenAddr), expectedCampaignAmount, "Campaign token balance incorrect");
        
        // 验证ActionManager收到了费用
        uint expectedActionManagerBalance = expectedPlatformFee + expectedQualityFee + expectedLotteryFee;
        assertEq(usdc.balanceOf(address(actionManager)), expectedActionManagerBalance, "ActionManager balance incorrect");
    }
    
    // 测试质量评论者奖励分配
    function test_QualityCommenterReward() public {
        // 先注资活动
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 用户发表评论
        vm.prank(user1);
        app.comment(topicId, "Great comment from user1");
        
        vm.prank(user2);
        app.comment(topicId, "Good comment from user2");
        
        vm.prank(user3);
        app.comment(topicId, "Average comment from user3");
        
        // 用户互相点赞，让user1的评论获得最多点赞
        vm.prank(user2);
        app.like(topicId, 0); // 点赞user1的评论
        
        vm.prank(user3);
        app.like(topicId, 0); // 点赞user1的评论
        
        vm.prank(user1);
        app.like(topicId, 1); // user1点赞user2的评论
        
        // 记录用户余额
        uint user1BalanceBefore = usdc.balanceOf(user1);
        uint user2BalanceBefore = usdc.balanceOf(user2);
        
        // 快进到活动结束
        vm.warp(block.timestamp + 8 days);
        
        // 结束活动（会自动分配奖励）
        app.endCampaign(campaignId);
        
        // 验证奖励分配
        uint user1BalanceAfter = usdc.balanceOf(user1);
        uint user2BalanceAfter = usdc.balanceOf(user2);
        
        // user1和user2应该获得质量评论者奖励（top 2）
        assertTrue(user1BalanceAfter > user1BalanceBefore, "User1 should receive quality commenter reward");
        assertTrue(user2BalanceAfter > user2BalanceBefore, "User2 should receive quality commenter reward");
        
        // 检查奖励分配信息
        (address[] memory topCommenters, , bool distributed) = app.getRewardDistributionInfo(campaignId);
        assertTrue(distributed, "Rewards should be distributed");
        assertEq(topCommenters.length, 2, "Should have 2 top commenters");
    }
    
    // 测试点赞者抽奖奖励
    function test_LikerLotteryReward() public {
        // 先注资活动
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 用户发表评论
        vm.prank(user1);
        app.comment(topicId, "Comment for lottery test");
        
        // 多个用户点赞
        vm.prank(user2);
        app.like(topicId, 0);
        
        vm.prank(user3);
        app.like(topicId, 0);
        
        // 记录点赞者余额
        uint user2BalanceBefore = usdc.balanceOf(user2);
        uint user3BalanceBefore = usdc.balanceOf(user3);
        
        // 快进到活动结束
        vm.warp(block.timestamp + 8 days);
        
        // 结束活动（会自动分配奖励）
        app.endCampaign(campaignId);
        
        // 验证至少有一个点赞者获得了抽奖奖励
        uint user2BalanceAfter = usdc.balanceOf(user2);
        uint user3BalanceAfter = usdc.balanceOf(user3);
        
        bool someoneWon = (user2BalanceAfter > user2BalanceBefore) || (user3BalanceAfter > user3BalanceBefore);
        assertTrue(someoneWon, "At least one liker should win the lottery");
        
        // 检查抽奖结果
        (, address[] memory luckyLikers, bool distributed) = app.getRewardDistributionInfo(campaignId);
        assertTrue(distributed, "Rewards should be distributed");
        assertTrue(luckyLikers.length > 0, "Should have lucky likers");
        assertTrue(luckyLikers.length <= 2, "Should not exceed max lottery winners");
    }
    
    // 测试平台费提取
    function test_PlatformFeeWithdrawal() public {
        // 先注资活动
        usdc.approve(address(app), 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        
        // 启动活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        
        // 快进到活动结束
        vm.warp(block.timestamp + 8 days);
        
        // 结束活动
        app.endCampaign(campaignId);
        
        // 记录admin余额
        uint adminBalanceBefore = usdc.balanceOf(admin);
        
        // 提取平台费
        app.withdrawPlatformFees(campaignId);
        
        // 验证admin收到了平台费
        uint adminBalanceAfter = usdc.balanceOf(admin);
        uint expectedPlatformFee = 2000 * 1e6 * 5 / 100; // 5% of 2000 USDC
        assertEq(adminBalanceAfter - adminBalanceBefore, expectedPlatformFee, "Admin should receive platform fee");
        
        // 验证费用池已清空
        assertEq(actionManager.platformFeePool(campaignId), 0, "Platform fee pool should be empty");
    }
}