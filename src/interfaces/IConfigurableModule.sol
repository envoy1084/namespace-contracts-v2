// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IConfigurableModule
/// @notice Base interface for Namespace modules with activation-scoped config.
interface IConfigurableModule {
    /// @notice Store module parameters for an activation.
    /// @dev Implementations should restrict this function to the Namespace controller.
    /// @param activationId Activation id created by the controller.
    /// @param configData ABI-encoded module configuration.
    function configure(bytes32 activationId, bytes calldata configData) external;
}
