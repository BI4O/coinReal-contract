// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {App} from "../src/core/App.sol";
import {USDC} from "../src/token/USDC.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {MockVRF} from "../src/chainlink/MockVRF.sol";

contract DeployApp is Script {
    UserManager public userManager;
    TopicManager public topicManager;
    ActionManager public actionManager;
    function run() external returns (App) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 部署USDC
        USDC usdc = new USDC();
        console.log("USDC deployed at:", address(usdc));

        // 部署MockVRF
        MockVRF mockVRF = new MockVRF();
        console.log("MockVRF deployed at:", address(mockVRF));

        // 部署UserManager
        userManager = new UserManager();

        // 部署TopicManager，传入费用分配参数
        topicManager = new TopicManager(
            address(usdc),
            5,  // 5% 平台费
            10, // 10% 质量评论者费
            5,  // 5% 点赞抽奖费
            2   // top 2 评论者
        );

        // 部署ActionManager
        actionManager = new ActionManager(
            address(topicManager), 
            address(userManager), 
            10 * 1e18, 
            5 * 1e18,
            address(mockVRF));

        // 设置owner
        userManager.setOwner(deployer);
        topicManager.setOwner(deployer);
        actionManager.setOwner(deployer);

        // 部署App
        App app = new App(
            address(usdc), 
            address(userManager), 
            address(topicManager), 
            address(actionManager),
            address(mockVRF)
        );
        console.log("App deployed at:", address(app));

        vm.stopBroadcast();
        console.log("=== Deployment completed ===");

        return app;
    }
}
