// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {UserManager} from "../src/core/UserManager.sol";

contract DebugUserManager is Script {
    UserManager public userManager;
    
    address constant ALICE = 0x1111111111111111111111111111111111111111;
    address constant BOB = 0x2222222222222222222222222222222222222222;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署UserManager
        userManager = new UserManager();
        console.log("UserManager deployed at:", address(userManager));
        
        vm.stopBroadcast();
        
        // 测试用户注册
        testUserRegistration();
    }
    
    function testUserRegistration() internal {
        console.log("=== Testing User Registration ===");
        
        // 检查Alice初始状态
        (uint aliceId, string memory aliceName, string memory aliceBio, string memory aliceEmail, bool aliceRegistered) = userManager.users(ALICE);
        console.log("Alice initial state:");
        console.log("  id:", aliceId);
        console.log("  registered:", aliceRegistered);
        
        // 检查Bob初始状态
        (uint bobId, string memory bobName, string memory bobBio, string memory bobEmail, bool bobRegistered) = userManager.users(BOB);
        console.log("Bob initial state:");
        console.log("  id:", bobId);
        console.log("  registered:", bobRegistered);
        
        // Alice注册
        console.log("Registering Alice...");
        vm.prank(ALICE);
        userManager._registerUser(ALICE, "Alice", "Blockchain enthusiast", "alice@example.com");
        console.log("Alice registered successfully");
        
        // 再次检查Alice状态
        (aliceId, aliceName, aliceBio, aliceEmail, aliceRegistered) = userManager.users(ALICE);
        console.log("Alice after registration:");
        console.log("  id:", aliceId);
        console.log("  registered:", aliceRegistered);
        
        // 再次检查Bob状态（应该还是未注册）
        (bobId, bobName, bobBio, bobEmail, bobRegistered) = userManager.users(BOB);
        console.log("Bob after Alice registration:");
        console.log("  id:", bobId);
        console.log("  registered:", bobRegistered);
        
        // Bob注册
        console.log("Registering Bob...");
        vm.prank(BOB);
        userManager._registerUser(BOB, "Bob", "Crypto trader", "bob@example.com");
        console.log("Bob registered successfully");
        
        // 最终检查两个用户状态
        (aliceId, aliceName, aliceBio, aliceEmail, aliceRegistered) = userManager.users(ALICE);
        console.log("Final Alice state:");
        console.log("  id:", aliceId);
        console.log("  registered:", aliceRegistered);
        
        (bobId, bobName, bobBio, bobEmail, bobRegistered) = userManager.users(BOB);
        console.log("Final Bob state:");
        console.log("  id:", bobId);
        console.log("  registered:", bobRegistered);
    }
} 