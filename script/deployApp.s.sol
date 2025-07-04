// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {App} from "../src/core/App.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {USDC} from "../src/token/USDC.sol";
import {MockVRF} from "../src/chainlink/MockVRF.sol";

contract DeployAppScript is Script {
    function run() public returns (App) {
        vm.startBroadcast();

        // 部署基础合约
        USDC usdc = new USDC();
        console.log("USDC deployed at:", address(usdc));

        UserManager userManager = new UserManager();
        console.log("UserManager deployed at:", address(userManager));

        TopicManager topicManager = new TopicManager(
            address(usdc),
            5,  // 5% 平台费
            10, // 10% 质量评论者费
            5,  // 5% 点赞抽奖费
            2   // top 2 评论者
        );
        console.log("TopicManager deployed at:", address(topicManager));

        // 部署VRF合约（本地测试使用MockVRF）
        MockVRF vrfContract = new MockVRF();
        console.log("VRF Contract (Mock) deployed at:", address(vrfContract));

        // 部署ActionManager（带有新功能）
        ActionManager actionManager = new ActionManager(
            address(topicManager),
            address(userManager),
            10 * 1e18,  // commentRewardAmount
            5 * 1e18,   // likeRewardAmount
            address(vrfContract),
            address(0), // commentTagFunctions - 本地测试暂不设置
            5044        // functionsSubscriptionId - 默认使用Sepolia订阅ID
        );
        console.log("ActionManager deployed at:", address(actionManager));

        // 部署App合约
        App app = new App(
            address(usdc),
            address(userManager),
            address(topicManager),
            address(actionManager),
            address(vrfContract)
        );
        console.log("App deployed at:", address(app));

        // 设置各合约的owner为App合约
        userManager.setOwner(address(app));
        topicManager.setOwner(address(app));
        actionManager.setOwner(address(app));

        // 设置ActionManager引用（现在App是owner，可以调用）
        app.setActionManager();

        // 输出部署信息
        console.log("\n=== Local Deployment Summary ===");
        console.log("USDC:", address(usdc));
        console.log("UserManager:", address(userManager));
        console.log("TopicManager:", address(topicManager));
        console.log("ActionManager:", address(actionManager));
        console.log("VRF Contract (Mock):", address(vrfContract));
        console.log("App:", address(app));

        console.log("\n=== Local Testing Notes ===");
        console.log("1. Using MockVRF for local testing");
        console.log("2. Functions contract not set - use setCommentTagFunctions() if needed");
        console.log("3. All contracts owned by App contract");
        console.log("4. Ready for local testing and development");

        vm.stopBroadcast();
        return app;
    }
}
