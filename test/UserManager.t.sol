// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {UserManager} from "../src/core/UserManager.sol";

contract UserManagerTest is Test {
    UserManager userManager;
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        userManager = new UserManager();
    }

    function test_UserManagerRegister() public {
        userManager.registerUser(user1, "Alice", "bio", "alice@example.com");
        assertTrue(userManager.getUserInfo(user1).registered);
    }

    function test_UserManagerUpdateUser() public {
        userManager.registerUser(user1, "Alice", "bio", "alice@example.com");
        userManager.updateUser(user1, "Alice2", "bio2", "alice2@example.com");
        assertEq(userManager.getUserInfo(user1).name, "Alice2");
    }

    function test_UserManagerDeleteUser() public {
        userManager.registerUser(user1, "Alice", "bio", "alice@example.com");
        userManager.deleteUser(user1);
        assertFalse(userManager.getUserInfo(user1).registered);
    }

    function test_UserManagerGetUserById() public {
        userManager.registerUser(user1, "Alice", "bio", "alice@example.com");
        assertEq(userManager.getUserInfoById(0).name, "Alice");
    }

    function test_UserManagerDoubleRegister() public {
        userManager.registerUser(user1, "Alice", "bio", "alice@example.com");
        vm.expectRevert();
        userManager.registerUser(user1, "Alice", "bio", "alice@example.com");
    }
} 