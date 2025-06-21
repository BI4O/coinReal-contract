// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {App} from "../src/core/App.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";

contract VerifyDeployment is Script {
    App public app;
    
    function run() external {
        // 从部署记录中获取App地址
        address appAddress = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // 从部署输出中获取
        app = App(appAddress);
        
        console.log("=== Verifying Deployment ===");
        console.log("App Address:", appAddress);
        
        verifyUsers();
        verifyComments();
        verifyLikes();
        
        console.log("=== Verification Complete ===");
    }
    
    function verifyUsers() internal view {
        console.log("\n--- Verifying Users ---");
        
        // 检查特定用户 (使用Anvil的第二个账户地址)
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Alice的地址
        UserManager userManager = app.userManager();
        
        UserManager.User memory aliceInfo = userManager.getUserInfo(alice);
        if (aliceInfo.registered) {
            console.log("Alice is registered");
            console.log("Alice name:", aliceInfo.name);
        } else {
            console.log("Alice is NOT registered");
        }
        
        // 检查其他用户
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        UserManager.User memory bobInfo = userManager.getUserInfo(bob);
        if (bobInfo.registered) {
            console.log("Bob is registered");
            console.log("Bob name:", bobInfo.name);
        } else {
            console.log("Bob is NOT registered");
        }
    }
    
    function verifyComments() internal view {
        console.log("\n--- Verifying Comments ---");
        
        // 检查评论总数
        uint256 commentCount = app.getGlobalCommentsCount();
        console.log("Total comments:", commentCount);
        
        // 检查第一条评论
        if (commentCount > 0) {
            ActionManager.Comment memory comment = app.getComment(0);
            console.log("Comment 0 user:", comment.user);
            console.log("Comment 0 topicId:", comment.topicId);
            console.log("Comment 0 deleted:", comment.isDelete);
        }
        
        // 检查有效评论数
        uint256 validComments = app.getValidCommentsCount();
        console.log("Valid comments:", validComments);
    }
    
    function verifyLikes() internal view {
        console.log("\n--- Verifying Likes ---");
        
        // 检查点赞总数
        uint256 likeCount = app.getGlobalLikesCount();
        console.log("Total likes:", likeCount);
        
        // 检查第一条点赞
        if (likeCount > 0) {
            ActionManager.Like memory like = app.getLike(0);
            console.log("Like 0 user:", like.user);
            console.log("Like 0 commentId:", like.commentId);
        }
        
        // 检查第一条评论的点赞数
        if (app.getGlobalCommentsCount() > 0) {
            uint256 comment0Likes = app.getCommentLikeCount(0);
            console.log("Comment 0 like count:", comment0Likes);
        }
    }
} 