// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title IPolicyModule
/// @notice Stacked approval checks for Namespace mints and renewals.
interface IPolicyModule is IConfigurableModule {
    /// @notice Validate a mint.
    /// @dev Revert with a module-specific error if the mint is not allowed.
    /// @param ctx Shared mint context.
    /// @param runtimeData Per-mint data for this policy, e.g. Merkle proof.
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData) external;

    /// @notice Validate a renewal.
    /// @dev Revert with a module-specific error if the renewal is not allowed.
    /// @param ctx Shared renewal context.
    /// @param runtimeData Per-renewal data for this policy.
    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData) external;
}
