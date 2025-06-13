// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {App} from "../src/core/App.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";

contract DebugApp is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying test contracts for debugging...");
        
        // 部署Manager合约
        UserManager userManager = new UserManager();
        console.log("UserManager deployed at:", address(userManager));
        
        TopicManager topicManager = new TopicManager();  // TopicManager继承了TopicBaseManager
        console.log("TopicManager deployed at:", address(topicManager));
        
        ActionManager actionManager = new ActionManager();
        console.log("ActionManager deployed at:", address(actionManager));
        
        // 部署App合约 - 只需要3个Manager
        App app = new App(
            address(userManager),
            address(topicManager),
            address(actionManager),
            deployer
        );
        console.log("App deployed at:", address(app));
        
        vm.stopBroadcast();
        
        // 测试用户注册
        address testUser = 0x1111111111111111111111111111111111111111;
        
        vm.prank(testUser);
        app.registerUser("TestUser", "Test Bio", "test@example.com");
        
        // 查询用户
        UserManager.User memory user = app.getUser(testUser);
        console.log("User registered:");
        console.log("- Name:", user.name);
        console.log("- Bio:", user.bio);
        console.log("- Email:", user.email);
        console.log("- Registered:", user.registered);
        console.log("- User ID:", user.id);
    }
} 