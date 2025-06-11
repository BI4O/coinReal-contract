// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟注资用的项目方token
contract ProjectToken is ERC20 {
    address public deployer;
    uint256 public price; // 项目方token的美元价格
    constructor() ERC20("ProjectToken", "PT") {
        deployer = msg.sender;
        price = 1e6; // 1USDC
    }
    function deployerMint(uint256 amount) public {
        require(msg.sender == deployer, "Only deployer can mint");
        _mint(msg.sender, amount);
    }
    // 用来模拟项目方token的波动
    function setPrice(uint256 _price) public {
        require(msg.sender == deployer, "Only deployer can set price");
        price = _price;
    }
}