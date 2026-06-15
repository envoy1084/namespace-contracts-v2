// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IAddrResolver
/// @notice Minimal ETH address resolver setter used by Namespace post hooks.
interface IAddrResolver {
    /// @notice Set the ETH address record for a node.
    /// @param node ENS namehash node.
    /// @param addr_ ETH address to store.
    function setAddr(bytes32 node, address addr_) external;
}
