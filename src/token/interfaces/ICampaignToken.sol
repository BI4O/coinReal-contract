// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUSDC.sol";
import "./IProjectToken.sol";

/**
 * @title ICampaignToken
 * @notice 活动代币接口
 */
interface ICampaignToken is IERC20 {
    function usdc() external view returns (IUSDC);
    function projectToken() external view returns (IProjectToken);
    function topicId() external view returns (uint);
    function jackpotStart() external view returns (uint256);
    function jackpotRealTime() external view returns (uint256);
    function minJackpot() external view returns (uint256);
    function minDuration() external view returns (uint256);
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function isActive() external view returns (bool);
    function initialized() external view returns (bool);
    function usdcPerMillionCPToken() external view returns (uint256);
    function ptokenPerMillionCPToken() external view returns (uint256);
    function usdcPerMillionCPTokenFinal() external view returns (uint256);
    function ptokenPerMillionCPTokenFinal() external view returns (uint256);
    
    function setUSDC(address _usdcAddr) external;
    function initialize(string memory _tokenName, string memory _tokenSymbol, uint _topicId, address _projectTokenAddr) external;
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function getFundedUSDC() external view returns(uint256);
    function getFundedProjectToken() external view returns(uint256);
    function getTotalFundedInUSD() external view returns(uint256);
    function start(uint256 _endTime) external;
    function updateJackpot() external returns(uint256, uint256, uint256);
    function finish() external returns(bool);
    function finishByLowTotalJackpot() external returns(bool);
    function claim() external;
} 