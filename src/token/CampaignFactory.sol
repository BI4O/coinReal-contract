// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {CampaignToken} from "./Campaign.sol";

contract CampaignFactory {
    address public campaignTokenImplementation;
    address public usdc;
    
    constructor(address _usdc) {
        // 部署campaign token模板
        campaignTokenImplementation = address(new CampaignToken());
        usdc = _usdc;
    }
    
    // 创建新的campaign token实例
    function createCampaignToken(
        string memory _name,
        string memory _symbol,
        uint _topicId,
        address _projectTokenAddr
    ) external returns (address) {
        // 使用最小代理创建campaign token
        address campaignClone = Clones.clone(campaignTokenImplementation);
        
        // 初始化clone
        CampaignToken c = CampaignToken(campaignClone);
        c.initialize(
            _name, 
            _symbol, 
            _topicId, 
            _projectTokenAddr
        );

        // 设置USDC
        c.setUSDC(usdc);
        
        return campaignClone;
    }
} 