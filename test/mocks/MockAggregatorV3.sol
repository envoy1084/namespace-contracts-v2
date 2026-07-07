// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockAggregatorV3 {
    uint8 public decimalsValue;
    uint80 public roundId = 1;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        decimalsValue = decimals_;
        answer = answer_;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return decimalsValue;
    }

    function setDecimals(uint8 decimals_) external {
        decimalsValue = decimals_;
    }

    function setRoundData(int256 answer_, uint256 updatedAt_) external {
        ++roundId;
        answer = answer_;
        startedAt = updatedAt_;
        updatedAt = updatedAt_;
        answeredInRound = roundId;
    }

    function setAnsweredInRound(uint80 answeredInRound_) external {
        answeredInRound = answeredInRound_;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
