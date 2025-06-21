// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICampaignFactory
 * @notice 活动代币工厂接口
 */
interface ICampaignFactory {
    function campaignTokenImplementation() external view returns (address);
    function usdc() external view returns (address);
    function createCampaignToken(
        string memory _name,
        string memory _symbol,
        uint _topicId,
        address _projectTokenAddr
    ) external returns (address);
} 