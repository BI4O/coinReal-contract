// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IUserManager
 * @notice 用户管理接口
 */
interface IUserManager {
    // 用户结构体
    struct User {
        uint id;                  // 用户id
        string name;              // 用户名称
        string bio;               // 用户简介
        string email;             // 用户邮箱
        bool registered;          // 是否已注册
    }
    
    // 查询函数
    function owner() external view returns (address);
    function nextUserId() external view returns (uint);
    function users(address user) external view returns (User memory);
    function usersById(uint id) external view returns (address);
    
    // 管理函数
    function setOwner(address _owner) external;
    
    // 用户操作
    function registerUser(address _user, string memory _name, string memory _bio, string memory _email) external;
    function updateUser(address _user, string memory _name, string memory _bio, string memory _email) external;
    function getUserInfo(address _user) external view returns (User memory);
    function getUserInfoById(uint _id) external view returns (User memory);
    function deleteUser(address _user) external;
} 