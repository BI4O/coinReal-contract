// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {App} from "../src/core/App.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {CampaignFactory} from "../src/token/CampaignFactory.sol";
import {USDC} from "../src/token/USDC.sol";
import {ProjectToken} from "../src/token/ProjectToken.sol";

contract DeployApp is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying contracts with deployer:", deployer);
        
        // 使用时间戳避免地址冲突
        uint256 timestamp = block.timestamp;
        
        // 部署USDC
        USDC usdc = new USDC();
        console.log("USDC deployed at:", address(usdc));
        
        // 部署ProjectToken
        ProjectToken projectToken = new ProjectToken();
        console.log("ProjectToken deployed at:", address(projectToken));
        
        // 部署CampaignFactory
        CampaignFactory campaignFactory = new CampaignFactory(
            address(usdc), 
            address(projectToken)
        );
        console.log("CampaignFactory deployed at:", address(campaignFactory));
        
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
        
        // 设置CampaignFactory
        app.setCampaignFactory(address(campaignFactory));
        console.log("CampaignFactory set successfully");
        
        // 设置默认奖励
        app.setRewards(10 * 1e18, 5 * 1e18); // 评论10个token，点赞5个token
        console.log("Default rewards set successfully");
        
        vm.stopBroadcast();
        
        console.log("=== Deployment completed ===");
        console.log("App address:", address(app));
        console.log("Contract size optimization successful!");
    }
}
