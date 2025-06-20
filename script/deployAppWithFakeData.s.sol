// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {App} from "../src/core/App.sol";
import {USDC} from "../src/token/USDC.sol";
import {DeployAppScript} from "./deployApp.s.sol";

contract DeployAppWithFakeData is Script {
    App public app;
    address constant ALICE = 0x1111111111111111111111111111111111111111;
    address constant BOB = 0x2222222222222222222222222222222222222222;
    address constant CHARLIE = 0x3333333333333333333333333333333333333333;
    address constant DIANA = 0x4444444444444444444444444444444444444444;
    address constant EVE = 0x5555555555555555555555555555555555555555;
    address constant BITCOIN_SPONSOR = 0x6666666666666666666666666666666666666666;
    address constant ETHEREUM_SPONSOR = 0x7777777777777777777777777777777777777777;
    address constant ADMIN = 0x8888888888888888888888888888888888888888;

    function run() external {
        // 部署App
        DeployAppScript deployApp = new DeployAppScript();
        app = deployApp.run();
        // 创建测试数据
        createTestData();
        console.log("=== Deployment with fake data completed ===");
    }

    function createTestData() internal {
        createUsers();
        createTopics();
        createCampaigns();
        createInteractions();
    }

    function createUsers() internal {
        vm.prank(ALICE); app.registerUser("Alice", unicode"区块链爱好者", "alice@example.com");
        vm.prank(BOB); app.registerUser("Bob", unicode"加密货币交易员", "bob@example.com");
        vm.prank(CHARLIE); app.registerUser("Charlie", unicode"DeFi开发者", "charlie@example.com");
        vm.prank(DIANA); app.registerUser("Diana", unicode"NFT收藏家", "diana@example.com");
        vm.prank(EVE); app.registerUser("Eve", unicode"Web3研究员", "eve@example.com");
        vm.prank(BITCOIN_SPONSOR); app.registerUser("BitcoinSponsor", unicode"Bitcoin投资机构", "sponsor@bitcoin.com");
        vm.prank(ETHEREUM_SPONSOR); app.registerUser("EthereumSponsor", unicode"Ethereum基金会", "sponsor@ethereum.org");
        vm.prank(ADMIN); app.registerUser("Admin", unicode"系统管理员", "admin@coinreal.com");
    }

    function createTopics() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startPrank(deployer);
        app.registerTopic("Bitcoin", unicode"比特币相关讨论", "BTC", 67000);
        app.registerTopic("Ethereum", unicode"以太坊生态讨论", "ETH", 3500);
        app.registerTopic("Solana", unicode"Solana网络相关内容", "SOL", 150);
        app.registerTopic("Doge", unicode"狗狗币社区", "DOGE", 1);
        app.registerTopic("XRP", unicode"Ripple和XRP讨论", "XRP", 1);
        vm.stopPrank();
    }

    function createCampaigns() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startPrank(deployer);
        app.registerCampaign(BITCOIN_SPONSOR, 0, unicode"Bitcoin牛市预测活动", unicode"预测比特币能否突破10万美元", address(0));
        app.registerCampaign(ETHEREUM_SPONSOR, 1, unicode"以太坊2.0升级讨论", unicode"讨论以太坊2.0升级对生态的影响", address(0));
        vm.stopPrank();
    }

    function createInteractions() internal {
        vm.prank(ALICE); app.comment(0, unicode"我认为比特币会在年底突破10万美元！");
        vm.prank(BOB); app.comment(0, unicode"现在的市场情况确实看涨，但也要注意风险。");
        vm.prank(CHARLIE); app.comment(1, unicode"以太坊2.0的PoS机制更加环保，值得期待。");
        vm.prank(DIANA); app.comment(1, unicode"质押奖励机制会吸引更多长期投资者。");
        vm.prank(EVE); app.comment(2, unicode"Solana的TPS确实很高，但网络稳定性还需要观察。");
        vm.prank(ALICE); app.comment(2, unicode"Solana的生态发展很迅速，DeFi项目质量越来越高。");
        vm.prank(BOB); app.comment(3, unicode"DOGE虽然是meme币，但社区力量不容小觑。");
        vm.prank(CHARLIE); app.comment(3, unicode"马斯克的支持让DOGE有了更多应用场景。");
        vm.prank(DIANA); app.comment(4, unicode"XRP在跨境支付领域有独特优势。");
        vm.prank(EVE); app.comment(4, unicode"Ripple与SEC的官司结果对XRP影响巨大。");
        // 点赞
        vm.prank(BOB); app.like(0, 0);
        vm.prank(CHARLIE); app.like(0, 0);
        vm.prank(DIANA); app.like(0, 0);
        vm.prank(ALICE); app.like(0, 1);
        vm.prank(EVE); app.like(0, 1);
        vm.prank(ALICE); app.like(1, 2);
        vm.prank(BOB); app.like(1, 2);
        vm.prank(EVE); app.like(1, 3);
        vm.prank(ALICE); app.like(2, 4);
        vm.prank(CHARLIE); app.like(2, 5);
        vm.prank(DIANA); app.like(3, 6);
        vm.prank(EVE); app.like(3, 7);
        vm.prank(ALICE); app.like(4, 8);
        vm.prank(BOB); app.like(4, 9);
    }
}
