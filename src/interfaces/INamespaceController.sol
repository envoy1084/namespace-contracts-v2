// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title INamespaceController
/// @notice Main entry point for activation-based Namespace subname minting.
interface INamespaceController {
    /// @notice Emitted when a namespace activation is created.
    event ActivationCreated(
        bytes32 indexed activationId, address indexed owner, address indexed registry, bytes32 parentNode
    );

    /// @notice Emitted when an activation is enabled or disabled.
    event ActivationStatusChanged(bytes32 indexed activationId, bool active);

    /// @notice Emitted after a module is configured for an activation.
    event ModuleConfigured(bytes32 indexed activationId, address indexed module, bytes32 indexed kind);

    /// @notice Emitted after a subname is minted.
    event SubnameMinted(
        bytes32 indexed activationId,
        bytes32 indexed labelHash,
        string label,
        address indexed owner,
        uint256 tokenId,
        address paymentToken,
        uint256 amount
    );

    /// @notice Emitted after a subname is renewed.
    event SubnameRenewed(
        bytes32 indexed activationId,
        bytes32 indexed labelHash,
        string label,
        uint256 tokenId,
        uint64 newExpiry,
        address paymentToken,
        uint256 amount
    );

    /// @notice Create and configure a namespace activation.
    /// @param config Activation configuration and module config payloads.
    /// @return activationId Created activation id.
    function activate(NamespaceTypes.ActivationConfig calldata config) external returns (bytes32 activationId);

    /// @notice Enable or disable an activation.
    /// @param activationId Activation id.
    /// @param active New active status.
    function setActivationStatus(bytes32 activationId, bool active) external;

    /// @notice Mint a subname through a stored activation.
    /// @param activationId Activation id.
    /// @param label Direct label to register.
    /// @param duration Registration duration in seconds.
    /// @param runtimeData Per-module runtime data.
    /// @return tokenId Token id returned by the ENSv2 registry.
    function mint(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable returns (uint256 tokenId);

    /// @notice Read public activation metadata.
    /// @param activationId Activation id.
    /// @return activation Public activation metadata.
    function getActivation(bytes32 activationId) external view returns (NamespaceTypes.Activation memory activation);
}
