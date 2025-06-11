// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {CampaignToken} from "./Campaign.sol";

contract CampaignFactory {
    address public campaignTokenImplementation;
    
    constructor() {
        // 部署campaign token模板
        campaignTokenImplementation = address(new CampaignToken());
    }
    
    // 创建新的campaign token实例
    function createCampaignToken(
        string memory _name,
        string memory _symbol,
        address _sponsor,
        address _appContract,
        uint _topicId
    ) external returns (address) {
        // 使用最小代理创建campaign token
        address campaignClone = Clones.clone(campaignTokenImplementation);
        
        // 初始化clone
        CampaignToken(campaignClone).initialize(_name, _symbol, _sponsor, _appContract, _topicId);
        
        return campaignClone;
    }
} 