// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IUSDC
 * @notice USDC代币接口
 */
interface IUSDC is IERC20 {
    function deployer() external view returns (address);
    function deployerMint(uint256 amount) external;
} 