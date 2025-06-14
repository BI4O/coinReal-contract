// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import {MockV3Aggregator} from "@chainlink/local/src/data-feeds/MockV3Aggregator.sol";
import {DataConsumerV3} from "src/chainlink/PriceFeed.sol";

contract PriceFeedTest is Test {
    MockV3Aggregator internal mockAggregator;
    DataConsumerV3 internal consumer;

    // 18 decimals
    uint8 constant DECIMALS = 18;
    // 初始价格 90000 * 1e18
    int256 constant INITIAL_PRICE = 90000 * 1e18;

    function setUp() public {
        // 部署mock aggregator
        mockAggregator = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        // 用cheatcode更改consumer中的dataFeed地址为mockAggregator
        consumer = new DataConsumerV3();
        // 替换dataFeed为mockAggregator
        vm.etch(address(consumer.dataFeed()), address(mockAggregator).code);
        vm.store(address(consumer), bytes32(uint256(0)), bytes32(uint256(uint160(address(mockAggregator)))));
    }

    function testPriceFluctuation() public {
        // 模拟价格波动
        int256[] memory prices = new int256[](5);
        prices[0] = 80000 * 1e18;
        prices[1] = 85000 * 1e18;
        prices[2] = 100000 * 1e18;
        prices[3] = 110000 * 1e18;
        prices[4] = 90000 * 1e18;

        for (uint256 i = 0; i < prices.length; i++) {
            mockAggregator.updateAnswer(prices[i]);
            int256 answer = consumer.getChainlinkDataFeedLatestAnswer();
            assertEq(answer, prices[i], "Price not synced correctly");
        }
    }
} 