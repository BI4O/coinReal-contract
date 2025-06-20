// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {App} from "../src/core/App.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {USDC} from "../src/token/USDC.sol";

contract DeployAppFujiScript is Script {
    // Fuji测试网已部署的合约地址
    address constant FUJI_VRF_CONTRACT = 0x61a892422aFaa9f7fb9Fd15E1eF66B8F174FD31b;
    address constant FUJI_FUNCTIONS_CONTRACT = 0x3d4AFaAd35E81C8Da51cf0bfC48f0E71C0BB8b2D;
    uint64 constant FUJI_FUNCTIONS_SUBSCRIPTION_ID = 15554;

    function run() public {
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

        // 部署ActionManager（使用Fuji已部署的Chainlink服务）
        ActionManager actionManager = new ActionManager(
            address(topicManager),
            address(userManager),
            10 * 1e18,  // commentRewardAmount
            5 * 1e18,   // likeRewardAmount
            FUJI_VRF_CONTRACT,
            FUJI_FUNCTIONS_CONTRACT,
            FUJI_FUNCTIONS_SUBSCRIPTION_ID
        );
        console.log("ActionManager deployed at:", address(actionManager));

        // 部署App合约
        App app = new App(
            address(usdc),
            address(userManager),
            address(topicManager),
            address(actionManager),
            FUJI_VRF_CONTRACT
        );
        console.log("App deployed at:", address(app));

        // 设置各合约的owner为App合约
        userManager.setOwner(address(app));
        topicManager.setOwner(address(app));
        actionManager.setOwner(address(app));

        // 设置ActionManager引用（现在App是owner，可以调用）
        app.setActionManager();

        // 输出部署信息
        console.log("\n=== Fuji Deployment Summary ===");
        console.log("USDC:", address(usdc));
        console.log("UserManager:", address(userManager));
        console.log("TopicManager:", address(topicManager));
        console.log("ActionManager:", address(actionManager));
        console.log("App:", address(app));

        console.log("\n=== Fuji Chainlink Services ===");
        console.log("VRF Contract:", FUJI_VRF_CONTRACT);
        console.log("Functions Contract:", FUJI_FUNCTIONS_CONTRACT);
        console.log("Functions Subscription ID:", FUJI_FUNCTIONS_SUBSCRIPTION_ID);

        console.log("\n=== Fuji Configuration Notes ===");
        console.log("1. Using production Chainlink VRF on Fuji");
        console.log("2. Using production Chainlink Functions on Fuji");
        console.log("3. VRF and Functions contracts have LINK token funding");
        console.log("4. All contracts owned by App contract");
        console.log("5. Ready for Fuji testnet testing");

        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on Snowtrace");
        console.log("2. Test AI tagging functionality");
        console.log("3. Test VRF lottery functionality");
        console.log("4. Monitor LINK token consumption");

        vm.stopBroadcast();
    }
} 