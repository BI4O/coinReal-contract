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

contract RewardTest is Test {
    App public app; 
    USDC public usdc;
    ProjectToken public projectToken;
    UserManager public userManager;
    TopicManager public topicManager;
    ActionManager public actionManager;
    
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
        
        // 部署管理合约
        userManager = new UserManager();
        topicManager = new TopicManager(address(usdc));
        actionManager = new ActionManager(
            address(topicManager), 
            address(userManager), 
            commentRewardAmount, 
            likeRewardAmount
        );
        
        // 部署App合约
        app = new App(
            address(usdc), 
            address(userManager), 
            address(topicManager), 
            address(actionManager)
        );
        
        // 设置各合约的owner为App
        userManager.setOwner(address(app));
        topicManager.setOwner(address(app));
        actionManager.setOwner(address(app));
        
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
    
    // 测试多个点赞的额外奖励累加
    function test_MultiLikeExtraReward() public {
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
        
        // 记录用户1初始代币余额（评论奖励后）
        uint initialBalance = campaignToken.balanceOf(user1);
        
        // 用户2点赞
        vm.prank(user2);
        app.like(topicId, 0);
        
        // 用户3点赞
        vm.prank(user3);
        app.like(topicId, 0);
        
        // 验证用户1获得了两次额外奖励
        uint finalBalance = campaignToken.balanceOf(user1);
        assertEq(finalBalance - initialBalance, commentRewardExtraAmount * 2);
    }
    
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
    
    // 测试多个活动的奖励
    function test_MultiCampaignReward() public {
        // 注册第二个活动
        uint campaignId2 = 1;
        app.registerCampaign(admin, topicId, "Second Campaign", "Second campaign description", address(projectToken));
        
        // 为两个活动注资
        usdc.approve(address(app), 4000 * 1e6);
        app.fundCampaignWithUSDC(campaignId, 2000 * 1e6);
        app.fundCampaignWithUSDC(campaignId2, 2000 * 1e6);
        
        // 启动两个活动
        app.startCampaign(campaignId, block.timestamp + 7 days);
        app.startCampaign(campaignId2, block.timestamp + 7 days);
        
        // 获取两个活动的代币地址
        address campaignTokenAddr1 = topicManager.getCampaignToken(campaignId);
        address campaignTokenAddr2 = topicManager.getCampaignToken(campaignId2);
        CampaignToken campaignToken1 = CampaignToken(campaignTokenAddr1);
        CampaignToken campaignToken2 = CampaignToken(campaignTokenAddr2);
        
        // 用户1发表评论
        vm.prank(user1);
        app.comment(topicId, "This is a test comment");
        
        // 验证用户1在两个活动中都获得了评论奖励
        assertEq(campaignToken1.balanceOf(user1), commentRewardAmount);
        assertEq(campaignToken2.balanceOf(user1), commentRewardAmount);
    }
    
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
}