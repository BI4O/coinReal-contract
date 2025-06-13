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

contract DeployAppWithFakeData is Script {
    App public app;
    UserManager public userManager;
    TopicManager public topicManager;  // TopicManager已经继承了TopicBaseManager
    ActionManager public actionManager;
    USDC public usdc;
    ProjectToken public projectToken;
    CampaignFactory public campaignFactory;
    
    // 假数据地址 - 20字节地址
    address constant ALICE = 0x1111111111111111111111111111111111111111;
    address constant BOB = 0x2222222222222222222222222222222222222222;
    address constant CHARLIE = 0x3333333333333333333333333333333333333333;
    address constant DIANA = 0x4444444444444444444444444444444444444444;
    address constant EVE = 0x5555555555555555555555555555555555555555;
    address constant BITCOIN_SPONSOR = 0x6666666666666666666666666666666666666666;
    address constant ETHEREUM_SPONSOR = 0x7777777777777777777777777777777777777777;
    address constant ADMIN = 0x8888888888888888888888888888888888888888;
    
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署所有基础合约
        deployContracts(deployer);
        
        vm.stopBroadcast();
        
        // 2. 创建测试数据
        createTestData();
        
        console.log("=== Deployment with fake data completed ===");
        console.log("App address:", address(app));
        console.log("CampaignFactory address:", address(campaignFactory));
        console.log("USDC address:", address(usdc));
        console.log("ProjectToken address:", address(projectToken));
    }
    
    function deployContracts(address deployer) internal {
        console.log("Deploying contracts...");
        
        // 使用时间戳避免地址冲突
        uint256 timestamp = block.timestamp;
        
        // 部署USDC
        usdc = new USDC();
        console.log("USDC deployed at:", address(usdc));
        
        // 部署ProjectToken
        projectToken = new ProjectToken();
        console.log("ProjectToken deployed at:", address(projectToken));
        
        // 部署CampaignFactory
        campaignFactory = new CampaignFactory(address(usdc), address(projectToken));
        console.log("CampaignFactory deployed at:", address(campaignFactory));
        
        // 部署Manager合约
        userManager = new UserManager();
        console.log("UserManager deployed at:", address(userManager));
        
        topicManager = new TopicManager();  // TopicManager继承了TopicBaseManager
        console.log("TopicManager deployed at:", address(topicManager));
        
        actionManager = new ActionManager();
        console.log("ActionManager deployed at:", address(actionManager));
        
        // 部署App合约 - 只需要3个Manager
        app = new App(
            address(userManager),
            address(topicManager),
            address(actionManager),
            deployer
        );
        console.log("App deployed at:", address(app));
        
        // 连接App和CampaignFactory
        app.setCampaignFactory(address(campaignFactory));
        console.log("App connected to CampaignFactory");
        
        // 设置默认奖励
        app.setRewards(10 * 1e18, 5 * 1e18); // 评论10个token，点赞5个token
        console.log("Default rewards set");
    }
    
    function createTestData() internal {
        console.log("Creating test data...");
        
        // 2. 创建用户数据
        createUsers();
        
        // 3. 创建话题数据
        createTopics();
        
        // 4. 创建Campaign数据
        createCampaigns();
        
        // 5. 创建用户互动数据
        createInteractions();
    }
    
    function createUsers() internal {
        console.log("Creating users...");
        
        // 模拟Alice注册
        vm.prank(ALICE);
        app.registerUser("Alice", unicode"区块链爱好者", "alice@example.com");
        
        // 模拟Bob注册
        vm.prank(BOB);
        app.registerUser("Bob", unicode"加密货币交易员", "bob@example.com");
        
        // 模拟Charlie注册
        vm.prank(CHARLIE);
        app.registerUser("Charlie", unicode"DeFi开发者", "charlie@example.com");
        
        // 模拟Diana注册
        vm.prank(DIANA);
        app.registerUser("Diana", unicode"NFT收藏家", "diana@example.com");
        
        // 模拟Eve注册
        vm.prank(EVE);
        app.registerUser("Eve", unicode"Web3研究员", "eve@example.com");
        
        // 模拟BitcoinSponsor注册
        vm.prank(BITCOIN_SPONSOR);
        app.registerUser("BitcoinSponsor", unicode"Bitcoin投资机构", "sponsor@bitcoin.com");
        
        // 模拟EthereumSponsor注册
        vm.prank(ETHEREUM_SPONSOR);
        app.registerUser("EthereumSponsor", unicode"Ethereum基金会", "sponsor@ethereum.org");
        
        // 模拟Admin注册
        vm.prank(ADMIN);
        app.registerUser("Admin", unicode"系统管理员", "admin@coinreal.com");
        
        console.log("Users created successfully");
    }
    
    function createTopics() internal {
        console.log("Creating topics...");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startPrank(deployer);
        
        // Bitcoin话题
        app.registerTopic(
            "Bitcoin",
            unicode"比特币相关讨论",
            "BTC",
            67000
        );
        
        // Ethereum话题
        app.registerTopic(
            "Ethereum",
            unicode"以太坊生态讨论",
            "ETH",
            3500
        );
        
        // Solana话题
        app.registerTopic(
            "Solana",
            unicode"Solana网络相关内容",
            "SOL",
            150
        );
        
        // Doge话题
        app.registerTopic(
            "Doge",
            unicode"狗狗币社区",
            "DOGE",
            1
        );
        
        // XRP话题
        app.registerTopic(
            "XRP",
            unicode"Ripple和XRP讨论",
            "XRP",
            1
        );
        
        vm.stopPrank();
        
        console.log("Topics created successfully");
    }
    
    function createCampaigns() internal {
        console.log("Creating campaigns...");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startPrank(deployer);
        
        // Bitcoin Campaign
        (bool success1, uint campaignId1) = app.registerCampaign(
            BITCOIN_SPONSOR,
            0, // Bitcoin topicId
            unicode"Bitcoin牛市预测活动",
            unicode"预测比特币能否突破10万美元"
        );
        require(success1, "Failed to create Bitcoin campaign");
        
        // Ethereum Campaign
        (bool success2, uint campaignId2) = app.registerCampaign(
            ETHEREUM_SPONSOR,
            1, // Ethereum topicId
            unicode"以太坊2.0升级讨论",
            unicode"讨论以太坊2.0升级对生态的影响"
        );
        require(success2, "Failed to create Ethereum campaign");
        
        vm.stopPrank();
        
        console.log("Campaigns created successfully");
        console.log("Bitcoin Campaign ID:", campaignId1);
        console.log("Ethereum Campaign ID:", campaignId2);
    }
    
    function createInteractions() internal {
        console.log("Creating user interactions...");
        
        // Alice评论Bitcoin话题
        vm.prank(ALICE);
        app.commentOnTopic(0, unicode"我认为比特币会在年底突破10万美元！");
        
        // Bob评论Bitcoin话题
        vm.prank(BOB);
        app.commentOnTopic(0, unicode"现在的市场情况确实看涨，但也要注意风险。");
        
        // Charlie评论Ethereum话题
        vm.prank(CHARLIE);
        app.commentOnTopic(1, unicode"以太坊2.0的PoS机制更加环保，值得期待。");
        
        // Diana评论Ethereum话题
        vm.prank(DIANA);
        app.commentOnTopic(1, unicode"质押奖励机制会吸引更多长期投资者。");
        
        // Eve评论Solana话题
        vm.prank(EVE);
        app.commentOnTopic(2, unicode"Solana的TPS确实很高，但网络稳定性还需要观察。");
        
        // Alice评论Solana话题
        vm.prank(ALICE);
        app.commentOnTopic(2, unicode"Solana的生态发展很迅速，DeFi项目质量越来越高。");
        
        // Bob评论Doge话题
        vm.prank(BOB);
        app.commentOnTopic(3, unicode"DOGE虽然是meme币，但社区力量不容小觑。");
        
        // Charlie评论Doge话题
        vm.prank(CHARLIE);
        app.commentOnTopic(3, unicode"马斯克的支持让DOGE有了更多应用场景。");
        
        // Diana评论XRP话题
        vm.prank(DIANA);
        app.commentOnTopic(4, unicode"XRP在跨境支付领域有独特优势。");
        
        // Eve评论XRP话题
        vm.prank(EVE);
        app.commentOnTopic(4, unicode"Ripple与SEC的官司结果对XRP影响巨大。");
        
        // 添加点赞互动
        console.log("Adding likes...");
        
        // Bob点赞Alice的第一条评论(commentId=0)
        vm.prank(BOB);
        app.likeComment(0);
        
        // Charlie点赞Alice的第一条评论
        vm.prank(CHARLIE);
        app.likeComment(0);
        
        // Diana点赞Alice的第一条评论
        vm.prank(DIANA);
        app.likeComment(0);
        
        // Alice点赞Bob的评论(commentId=1)
        vm.prank(ALICE);
        app.likeComment(1);
        
        // Eve点赞Bob的评论
        vm.prank(EVE);
        app.likeComment(1);
        
        // Alice点赞Charlie的评论(commentId=2)
        vm.prank(ALICE);
        app.likeComment(2);
        
        // Bob点赞Charlie的评论
        vm.prank(BOB);
        app.likeComment(2);
        
        // Eve点赞Diana的评论(commentId=3)
        vm.prank(EVE);
        app.likeComment(3);
        
        // Alice点赞Eve的评论(commentId=4)
        vm.prank(ALICE);
        app.likeComment(4);
        
        // Charlie点赞Alice的Solana评论(commentId=5)
        vm.prank(CHARLIE);
        app.likeComment(5);
        
        // Diana点赞Bob的Doge评论(commentId=6)
        vm.prank(DIANA);
        app.likeComment(6);
        
        // Eve点赞Charlie的Doge评论(commentId=7)
        vm.prank(EVE);
        app.likeComment(7);
        
        // Alice点赞Diana的XRP评论(commentId=8)
        vm.prank(ALICE);
        app.likeComment(8);
        
        // Bob点赞Eve的XRP评论(commentId=9)
        vm.prank(BOB);
        app.likeComment(9);
        
        console.log("User interactions created successfully");
    }
}
