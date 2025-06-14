// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {App} from "../src/core/App.sol";
import {USDC} from "../src/token/USDC.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";

contract AppTest is Test {
    App app;
    USDC usdc;
    address user = address(0x1);
    address admin = address(this);
    UserManager userManager;
    TopicManager topicManager;
    ActionManager actionManager;

    function setUp() public {
        usdc = new USDC();
        userManager = new UserManager();
        topicManager = new TopicManager(address(usdc));
        actionManager = new ActionManager(address(topicManager), address(userManager), 10 * 1e18, 5 * 1e18);
        app = new App(address(usdc), address(userManager), address(topicManager), address(actionManager));
        vm.prank(user);
        app.registerUser("Alice", "bio", "alice@example.com");
        vm.startPrank(admin);
        app.registerTopic("BTC", "desc", "0xBTC", 1000);
        app.registerCampaign(admin, 0, "BTC_Activity", "desc", address(0));
        vm.stopPrank();
    }

    function test_AppRegisterAndComment() public {
        vm.prank(user);
        app.comment(0, "hello");
        // 只要不revert即通过
    }

    function test_AppRegisterAndLike() public {
        vm.prank(user);
        app.comment(0, "hello");
        vm.prank(user);
        app.like(0, 0);
    }

    function test_AppCommentAndReward() public {
        vm.prank(user);
        app.comment(0, "hello");
        // 奖励逻辑可在ActionManagerTest中详细测
    }

    function test_AppLikeAndReward() public {
        vm.prank(user);
        app.comment(0, "hello");
        vm.prank(user);
        app.like(0, 0);
        // 奖励逻辑可在ActionManagerTest中详细测
    }

    function test_AppPermissionControl() public {
        address notRegistered = address(0x2);
        vm.prank(notRegistered);
        vm.expectRevert();
        app.comment(0, "fail");
    }

    function test_AttackDoubleRegister() public {
        // 在setUp()中已经注册了user，所以这里直接测试重复注册
        vm.prank(user);
        vm.expectRevert("User already registered");
        app.registerUser("Alice", "bio", "alice@example.com");
    }

    function test_AttackFakeTopic() public {
        vm.prank(user);
        vm.expectRevert();
        app.comment(99, "fail");
    }

    function test_AttackFakeUserComment() public {
        address notRegistered = address(0x2);
        vm.prank(notRegistered);
        vm.expectRevert();
        app.comment(0, "fail");
    }

    function test_AttackExceedCampaignLimit() public {
        vm.startPrank(admin);
        // setUp()中已经注册了1个campaign，现在再注册2个，总共3个达到限制
        app.registerCampaign(admin, 0, "A", "desc", address(0));
        app.registerCampaign(admin, 0, "B", "desc", address(0));
        // 尝试注册第4个，应该失败
        vm.expectRevert("Topic campaign limit reached");
        app.registerCampaign(admin, 0, "C", "desc", address(0));
        vm.stopPrank();
    }

    function test_AttackRewardAbuse() public {
        vm.prank(user);
        app.comment(0, "hello");
        vm.prank(user);
        app.like(0, 0);
        vm.prank(user);
        vm.expectRevert();
        app.like(0, 0);
    }
} 