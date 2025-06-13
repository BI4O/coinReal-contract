// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {CampaignToken} from "./Campaign.sol";

contract CampaignFactory {
    address public campaignTokenImplementation;
    address public usdc;
    address public projectToken;
    
    constructor(address _usdc, address _projectToken) {
        // 部署campaign token模板
        campaignTokenImplementation = address(new CampaignToken());
        usdc = _usdc;
        projectToken = _projectToken;
    }
    
    // 创建新的campaign token实例
    function createCampaignToken(
        string memory _name,
        string memory _symbol,
        uint _topicId
    ) external returns (address) {
        // 使用最小代理创建campaign token
        address campaignClone = Clones.clone(campaignTokenImplementation);
        
        // 初始化clone
        CampaignToken(campaignClone).initialize(_name, _symbol, _topicId, usdc, projectToken);
        
        return campaignClone;
    }
} 