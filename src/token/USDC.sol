// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟注资用的USDC
contract USDC is ERC20 {
    address public deployer;
    constructor() ERC20("USDC", "USDC") {
        deployer = msg.sender;
    }
    function deployerMint(uint256 amount) public {
        require(msg.sender == deployer, "Only deployer can mint");
        _mint(msg.sender, amount);
    }
}