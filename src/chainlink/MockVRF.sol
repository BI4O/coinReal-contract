// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockVRF
 * @dev Mock implementation of Chainlink VRF for testing purposes
 * Based on Chainlink VRF v2.5 interface
 */
contract MockVRF {
    uint256 private nonce;
    
    // Events to mimic Chainlink VRF
    event RandomWordsRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint32 numWords
    );
    
    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256[] randomWords
    );
    
    // Storage for requests
    mapping(uint256 => address) public requesters;
    mapping(uint256 => uint32) public numWordsRequested;
    mapping(uint256 => bool) public requestFulfilled;
    mapping(uint256 => uint256[]) public randomWords;
    
    /**
     * @dev Request random words (mock implementation)
     * @param numWords Number of random words to request
     * @return requestId The request ID
     */
    function requestRandomWords(uint32 numWords) external returns (uint256 requestId) {
        requestId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce)));
        nonce++;
        
        requesters[requestId] = msg.sender;
        numWordsRequested[requestId] = numWords;
        
        emit RandomWordsRequested(requestId, msg.sender, numWords);
        
        // In a real implementation, this would be fulfilled by Chainlink oracles
        // For testing, we'll fulfill it immediately with pseudo-random numbers
        _fulfillRandomWords(requestId, numWords);
        
        return requestId;
    }
    
    /**
     * @dev Get random words for a fulfilled request
     * @param requestId The request ID
     * @return words Array of random words
     */
    function getRandomWords(uint256 requestId) external view returns (uint256[] memory words) {
        require(requestFulfilled[requestId], "Request not fulfilled");
        return randomWords[requestId];
    }
    
    /**
     * @dev Internal function to fulfill random words (mock implementation)
     * @param requestId The request ID
     * @param numWords Number of words to generate
     */
    function _fulfillRandomWords(uint256 requestId, uint32 numWords) internal {
        require(!requestFulfilled[requestId], "Request already fulfilled");
        
        uint256[] memory words = new uint256[](numWords);
        
        // Generate pseudo-random numbers for testing
        // In production, this would be done by Chainlink oracles with verifiable randomness
        for (uint32 i = 0; i < numWords; i++) {
            words[i] = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao, // 替换 block.difficulty
                requestId,
                i,
                nonce
            )));
        }
        
        randomWords[requestId] = words;
        requestFulfilled[requestId] = true;
        
        emit RandomWordsFulfilled(requestId, words);
    }
    
    /**
     * @dev Check if a request has been fulfilled
     * @param requestId The request ID
     * @return fulfilled Whether the request has been fulfilled
     */
    function isRequestFulfilled(uint256 requestId) external view returns (bool fulfilled) {
        return requestFulfilled[requestId];
    }
} 