// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
用户表
0. 用户地址：msg.sender
1. 用户id：0开始，每次注册+1
2. 用户名称
3. 用户简介
4. 用户邮箱
*/

contract UserManager {
    // 用户，不需要排序
    uint public nextUserId;
    struct User {
        uint id;                  // 用户id
        string name;              // 用户名称
        string bio;               // 用户简介
        string email;             // 用户邮箱
        bool registered;          // 是否已注册
    }
    mapping(address => User) public users;
    mapping(uint => address) public usersById;

    // 增：用户注册
    function _registerUser(
        address _user,
        string memory _name, 
        string memory _bio, 
        string memory _email
    ) public {
        require(!users[_user].registered, "User already registered");
        require(bytes(_name).length > 0, "Name is required");
        users[_user] = User({
            id: nextUserId,
            name: _name,
            bio: _bio,
            email: _email,
            registered: true
        });
        usersById[nextUserId] = _user;
        nextUserId++;
    }

    // 改：用户更新
    function _updateUser(
        address _user,
        string memory _name, 
        string memory _bio, 
        string memory _email
    ) public {
        require(users[_user].registered, "User not registered");
        if (bytes(_name).length > 0) {
            users[_user].name = _name;
        }
        if (bytes(_bio).length > 0) {
            users[_user].bio = _bio;
        }
        if (bytes(_email).length > 0) {
            users[_user].email = _email;
        }
    }   

    // 查：用户查询，只能通过地址查询
    function _getUser(address _user) public view returns (User memory) {
        return users[_user];
    }

    // 查：用户查询，通过id查询
    function _getUserById(uint _id) public view returns (User memory) {
        return users[usersById[_id]];
    }

    // 删：删除用户
    function _deleteUser(address _user) public {
        delete users[_user];
        delete usersById[users[_user].id];
    }
}
