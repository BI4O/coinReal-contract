// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IProjectToken
 * @notice 项目代币接口
 */
interface IProjectToken is IERC20 {
    function deployer() external view returns (address);
    function price() external view returns (uint256);
    function deployerMint(uint256 amount) external;
    function setPrice(uint256 _price) external;
    function getPrice() external view returns (uint256);
} 