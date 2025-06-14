// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {UserManager} from "../src/core/UserManager.sol";
import {TopicManager} from "../src/core/TopicManager.sol";
import {ActionManager} from "../src/core/ActionManager.sol";
import {USDC} from "../src/token/USDC.sol";

contract ActionManagerTest is Test {
    UserManager userManager;
    TopicManager topicManager;
    ActionManager actionManager;
    USDC usdc;
    address user = address(0x1);

    function setUp() public {
        usdc = new USDC();
        userManager = new UserManager();
        topicManager = new TopicManager(address(usdc));
        actionManager = new ActionManager(address(topicManager), address(userManager), 10 * 1e18, 5 * 1e18);
        userManager.registerUser(user, "Alice", "bio", "alice@example.com");
        topicManager.registerTopic("BTC", "desc", "0xBTC", 1000);
    }

    function test_ActionManagerAddComment() public {
        (bool ok, uint id) = actionManager.addComment(0, user, "hello");
        assertTrue(ok);
        assertEq(actionManager.getComment(id).content, "hello");
    }

    function test_ActionManagerAddLike() public {
        actionManager.addComment(0, user, "hello");
        (bool ok, uint id) = actionManager.addLike(0, 0, user);
        assertTrue(ok);
        assertEq(actionManager.getLike(id).commentId, 0);
    }

    function test_ActionManagerAddTags() public {
        (, uint id) = actionManager.addComment(0, user, "hello");
        string[] memory tags = new string[](1);
        tags[0] = "tag1";
        actionManager.addTags(id, tags);
        assertEq(actionManager.getCommentTags(id)[0], "tag1");
    }

    function test_ActionManagerDeleteComment() public {
        actionManager.addComment(0, user, "hello");
        vm.prank(user);
        actionManager.deleteComment(0);
        assertTrue(actionManager.getComment(0).isDelete);
    }

    function test_ActionManagerDoubleLike() public {
        actionManager.addComment(0, user, "hello");
        actionManager.addLike(0, 0, user);
        vm.expectRevert();
        actionManager.addLike(0, 0, user);
    }
} 