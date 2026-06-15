// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IAggregatorV3
/// @notice Minimal Chainlink AggregatorV3-compatible interface used by USD pricing modules.
interface IAggregatorV3 {
    /// @notice Number of decimals used by oracle answers.
    function decimals() external view returns (uint8);

    /// @notice Latest oracle round data.
    /// @return roundId Round id.
    /// @return answer Price answer.
    /// @return startedAt Timestamp when the round started.
    /// @return updatedAt Timestamp when the answer was updated.
    /// @return answeredInRound Round that produced the answer.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
