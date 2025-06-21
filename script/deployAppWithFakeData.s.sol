// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {App} from "../src/core/App.sol";
import {USDC} from "../src/token/USDC.sol";
import {DeployAppScript} from "./deployApp.s.sol";

contract DeployAppWithFakeData is Script {
    App public app;
    
    // 用户私钥 (Anvil的前10个账户)
    uint256 constant ALICE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant BOB_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 constant CHARLIE_KEY = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    uint256 constant DIANA_KEY = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;
    uint256 constant EVE_KEY = 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba;
    uint256 constant BITCOIN_SPONSOR_KEY = 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e;
    uint256 constant ETHEREUM_SPONSOR_KEY = 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356;
    uint256 constant ADMIN_KEY = 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97;

    function run() external {
        console.log("=== Starting deployment with fake data ===");
        
        // 部署App
        DeployAppScript deployApp = new DeployAppScript();
        app = deployApp.run();
        console.log("App deployed successfully");
        
        // 创建测试数据
        createTestData();
        
        console.log("=== Deployment with fake data completed ===");
        console.log("App contract address:", address(app));
    }

    function createTestData() internal {
        // 创建用户
        createUsers();
        
        // 创建话题
        createTopics();
        
        // 创建活动
        createCampaigns();
        
        // 创建交互
        createInteractions();
    }

    function createUsers() internal {
        console.log("Creating users...");
        
        vm.broadcast(ALICE_KEY);
        app.registerUser("Alice", unicode"区块链爱好者", "alice@example.com");
        
        vm.broadcast(BOB_KEY);
        app.registerUser("Bob", unicode"加密货币交易员", "bob@example.com");
        
        vm.broadcast(CHARLIE_KEY);
        app.registerUser("Charlie", unicode"DeFi开发者", "charlie@example.com");
        
        vm.broadcast(DIANA_KEY);
        app.registerUser("Diana", unicode"NFT收藏家", "diana@example.com");
        
        vm.broadcast(EVE_KEY);
        app.registerUser("Eve", unicode"Web3研究员", "eve@example.com");
        
        vm.broadcast(BITCOIN_SPONSOR_KEY);
        app.registerUser("BitcoinSponsor", unicode"Bitcoin投资机构", "sponsor@bitcoin.com");
        
        vm.broadcast(ETHEREUM_SPONSOR_KEY);
        app.registerUser("EthereumSponsor", unicode"Ethereum基金会", "sponsor@ethereum.org");
        
        vm.broadcast(ADMIN_KEY);
        app.registerUser("Admin", unicode"系统管理员", "admin@coinreal.com");
        
        console.log("Users created successfully");
    }

    function createTopics() internal {
        console.log("Creating topics...");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.broadcast(deployerPrivateKey);
        app.registerTopic("Bitcoin", unicode"比特币相关讨论", "BTC", 67000);
        
        vm.broadcast(deployerPrivateKey);
        app.registerTopic("Ethereum", unicode"以太坊生态讨论", "ETH", 3500);
        
        vm.broadcast(deployerPrivateKey);
        app.registerTopic("Solana", unicode"Solana网络相关内容", "SOL", 150);
        
        vm.broadcast(deployerPrivateKey);
        app.registerTopic("Doge", unicode"狗狗币社区", "DOGE", 1);
        
        vm.broadcast(deployerPrivateKey);
        app.registerTopic("XRP", unicode"Ripple和XRP讨论", "XRP", 1);
        
        console.log("Topics created successfully");
    }

    function createCampaigns() internal {
        console.log("Creating campaigns...");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bitcoinSponsor = vm.addr(BITCOIN_SPONSOR_KEY);
        address ethereumSponsor = vm.addr(ETHEREUM_SPONSOR_KEY);
        
        vm.broadcast(deployerPrivateKey);
        app.registerCampaign(bitcoinSponsor, 0, unicode"Bitcoin牛市预测活动", unicode"预测比特币能否突破10万美元", address(0));
        
        vm.broadcast(deployerPrivateKey);
        app.registerCampaign(ethereumSponsor, 1, unicode"以太坊2.0升级讨论", unicode"讨论以太坊2.0升级对生态的影响", address(0));
        
        console.log("Campaigns created successfully");
    }

    function createInteractions() internal {
        console.log("Creating interactions...");
        
        // 创建评论
        vm.broadcast(ALICE_KEY);
        app.comment(0, unicode"我认为比特币会在年底突破10万美元！");
        
        vm.broadcast(BOB_KEY);
        app.comment(0, unicode"现在的市场情况确实看涨，但也要注意风险。");
        
        vm.broadcast(CHARLIE_KEY);
        app.comment(1, unicode"以太坊2.0的PoS机制更加环保，值得期待。");
        
        vm.broadcast(DIANA_KEY);
        app.comment(1, unicode"质押奖励机制会吸引更多长期投资者。");
        
        vm.broadcast(EVE_KEY);
        app.comment(2, unicode"Solana的TPS确实很高，但网络稳定性还需要观察。");
        
        vm.broadcast(ALICE_KEY);
        app.comment(2, unicode"Solana的生态发展很迅速，DeFi项目质量越来越高。");
        
        vm.broadcast(BOB_KEY);
        app.comment(3, unicode"DOGE虽然是meme币，但社区力量不容小觑。");
        
        vm.broadcast(CHARLIE_KEY);
        app.comment(3, unicode"马斯克的支持让DOGE有了更多应用场景。");
        
        vm.broadcast(DIANA_KEY);
        app.comment(4, unicode"XRP在跨境支付领域有独特优势。");
        
        vm.broadcast(EVE_KEY);
        app.comment(4, unicode"Ripple与SEC的官司结果对XRP影响巨大。");
        
        // 创建点赞
        vm.broadcast(BOB_KEY); app.like(0, 0);
        vm.broadcast(CHARLIE_KEY); app.like(0, 0);
        vm.broadcast(DIANA_KEY); app.like(0, 0);
        vm.broadcast(ALICE_KEY); app.like(0, 1);
        vm.broadcast(EVE_KEY); app.like(0, 1);
        vm.broadcast(ALICE_KEY); app.like(1, 2);
        vm.broadcast(BOB_KEY); app.like(1, 2);
        vm.broadcast(EVE_KEY); app.like(1, 3);
        vm.broadcast(ALICE_KEY); app.like(2, 4);
        vm.broadcast(CHARLIE_KEY); app.like(2, 5);
        vm.broadcast(DIANA_KEY); app.like(3, 6);
        vm.broadcast(EVE_KEY); app.like(3, 7);
        vm.broadcast(ALICE_KEY); app.like(4, 8);
        vm.broadcast(BOB_KEY); app.like(4, 9);
        
        console.log("Interactions created successfully");
    }
}
