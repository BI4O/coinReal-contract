// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title CampaignLotteryVRF
 * @dev 基于Chainlink VRF v2.5实现的活动抽奖合约
 * 直接使用campaignId进行操作，简化接口

 这个合约已经部署在avax fuji了，不需要用foundry来部署
 而且现在已经有10LINK代币的余额，可以直接用

 地址：0x61a892422aFaa9f7fb9Fd15E1eF66B8F174FD31b
 Owner：0x802f71cBf691D4623374E8ec37e32e26d5f74d87
 只有Owner才可以reset，所以注意app的owner也用这个才行
 */
contract CampaignLotteryVRF is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
    event LotteryRequested(uint256 campaignId, uint32 numWords, uint256 maxRange, uint256 count);
    event LotteryCompleted(uint256 campaignId, uint256[] luckyIds);
    event LotteryReset(uint256 campaignId);

    struct LotteryInfo {
        bool isRequested;     // 是否已请求抽奖
        bool fulfilled;       // 抽奖是否已完成
        uint256 maxRange;     // 随机数范围上限（从0到maxRange-1）
        uint256 count;        // 需要选择的随机数数量
        uint256[] luckyIds;   // 选出的幸运ID列表
    }
    
    // campaignId到抽奖信息的映射
    mapping(uint256 => LotteryInfo) public campaignLotteries;
    
    // requestId到campaignId的映射
    mapping(uint256 => uint256) private requestToCampaign;
    
    // 回调函数的gas限制，根据需要调整
    uint32 public callbackGasLimit = 300000;
    
    // 确认区块数，默认为3
    uint16 public requestConfirmations = 3;
    
    // Sepolia测试网的LINK代币地址
    address public linkAddress = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    
    // Sepolia测试网的VRF Wrapper地址
    address public wrapperAddress = 0x327B83F409E1D5f13985c6d0584420FA648f1F56;
    
    constructor() 
        ConfirmedOwner(msg.sender)
        VRFV2PlusWrapperConsumerBase(wrapperAddress)
    {}
    
    /**
     * @dev 为指定活动请求抽奖
     * @param campaignId 活动ID
     * @param maxRange 随机数范围上限（从0到maxRange-1）
     * @param count 需要选择的幸运者数量
     * @param enableNativePayment 是否使用原生代币支付（true为ETH，false为LINK）
     */
    function setLotteryByCampaignId(
        uint256 campaignId,
        uint256 maxRange,
        uint256 count,
        bool enableNativePayment
    ) external onlyOwner {
        require(count <= maxRange, "Count must be less than or equal to maxRange");
        require(count > 0, "Count must be greater than 0");
        require(!campaignLotteries[campaignId].isRequested || !campaignLotteries[campaignId].fulfilled, 
                "Lottery already completed for this campaign");
        
        // 请求的随机数数量需要等于count，用于生成不重复的随机数
        uint32 numWords = uint32(count);
        
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
        
        uint256 requestId;
        
        if (enableNativePayment) {
            (requestId, ) = requestRandomnessPayInNative(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        } else {
            (requestId, ) = requestRandomness(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        }
        
        // 初始化或更新活动抽奖信息
        campaignLotteries[campaignId] = LotteryInfo({
            isRequested: true,
            fulfilled: false,
            maxRange: maxRange,
            count: count,
            luckyIds: new uint256[](0)
        });
        
        // 记录requestId到campaignId的映射
        requestToCampaign[requestId] = campaignId;
        
        emit LotteryRequested(campaignId, numWords, maxRange, count);
    }
    
    /**
     * @dev Chainlink VRF回调函数，接收随机数并处理抽奖结果
     */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 campaignId = requestToCampaign[_requestId];
        require(campaignLotteries[campaignId].isRequested, "Campaign lottery not requested");
        require(!campaignLotteries[campaignId].fulfilled, "Campaign lottery already fulfilled");
        
        LotteryInfo storage lottery = campaignLotteries[campaignId];
        uint256 maxRange = lottery.maxRange;
        uint256 count = lottery.count;
        
        // 创建一个数组存储幸运ID
        uint256[] memory luckyIds = new uint256[](count);
        
        // 用于跟踪已选择的数字
        bool[] memory selected = new bool[](maxRange);
        
        // 从随机数中选择不重复的幸运ID
        for (uint256 i = 0; i < count; i++) {
            uint256 randomNumber = _randomWords[i] % maxRange; // 范围从0到maxRange-1
            uint256 attempts = 0;
            
            // 如果随机数已被选中，则寻找下一个未被选中的数字
            while (selected[randomNumber] && attempts < maxRange) {
                randomNumber = (randomNumber + 1) % maxRange;
                attempts++;
            }
            
            // 如果尝试了maxRange次仍找不到未选中的数字，则顺序查找
            if (selected[randomNumber]) {
                for (uint256 j = 0; j < maxRange; j++) {
                    if (!selected[j]) {
                        randomNumber = j;
                        break;
                    }
                }
            }
            
            selected[randomNumber] = true;
            luckyIds[i] = randomNumber;
        }
        
        // 存储抽奖结果
        lottery.luckyIds = luckyIds;
        lottery.fulfilled = true;
        
        emit LotteryCompleted(campaignId, luckyIds);
    }
    
    /**
     * @dev 获取活动的幸运ID列表
     * @param campaignId 活动ID
     * @return isRequested 是否已请求抽奖
     * @return fulfilled 抽奖是否已完成
     * @return luckyIds 幸运ID列表
     */
    function getCampaignLuckyIds(uint256 campaignId)
        external
        view
        returns (
            bool isRequested,
            bool fulfilled,
            uint256[] memory luckyIds
        )
    {
        LotteryInfo memory lottery = campaignLotteries[campaignId];
        return (
            lottery.isRequested,
            lottery.fulfilled,
            lottery.luckyIds
        );
    }
    
    /**
     * @dev 重置指定活动的抽奖数据
     * @param campaignId 活动ID
     */
    function resetVRF(uint256 campaignId) external onlyOwner {
        delete campaignLotteries[campaignId];
        emit LotteryReset(campaignId);
    }
    
    /**
     * @dev 批量重置多个活动的抽奖数据
     * @param campaignIds 活动ID数组
     */
    function batchResetVRF(uint256[] calldata campaignIds) external onlyOwner {
        for (uint256 i = 0; i < campaignIds.length; i++) {
            delete campaignLotteries[campaignIds[i]];
            emit LotteryReset(campaignIds[i]);
        }
    }
    
    /**
     * @dev 重置所有活动的抽奖数据（危险操作，谨慎使用）
     * @param confirmationCode 确认代码，必须为"RESET_ALL_VRF_DATA"
     */
    function resetAllVRF(string calldata confirmationCode) external onlyOwner {
        require(
            keccak256(abi.encodePacked(confirmationCode)) == 
            keccak256(abi.encodePacked("RESET_ALL_VRF_DATA")),
            "Invalid confirmation code"
        );
        // 注意：这个函数不会实际删除所有数据，因为无法遍历映射
        // 它只是作为一个标记，表示所有数据都应该被视为已重置
        emit LotteryReset(type(uint256).max); // 使用最大uint256值表示所有活动
    }
    
    /**
     * @dev 提取合约中剩余的LINK代币
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
    
    /**
     * @dev 提取合约中剩余的原生代币(ETH)
     * @param amount 提取金额，单位为wei
     */
    function withdrawNative(uint256 amount) external onlyOwner {
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "withdrawNative failed");
    }
    
    /**
     * @dev 接收ETH的回退函数
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    event Received(address sender, uint256 amount);
}