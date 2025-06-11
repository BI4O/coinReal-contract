// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UserManager {
    // 用户，不需要排序
    uint public nextUserId;
    struct User {
        uint id;                  // 用户id
        string name;              // 用户名称
        string bio;               // 用户简介
        string email;             // 用户邮箱
    }
    mapping(address => User) public users;

    // 用户注册
    function _registerUser(
        string memory _name, 
        string memory _bio, 
        string memory _email
    ) internal {
        require(users[msg.sender].id == 0, "User already registered");
        users[msg.sender] = User({
            id: nextUserId++,
            name: _name,
            bio: _bio,
            email: _email
        });
        nextUserId++;
    }
    // 用户查询
    function _getUser(address _user) internal view returns (User memory) {
        return users[_user];
    }
}
