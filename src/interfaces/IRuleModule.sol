// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title IRuleModule
/// @notice Rule modules validate mints/renewals and return deterministic effects for the controller engine.
interface IRuleModule is IConfigurableModule {
    /// @notice Evaluate a mint.
    /// @dev Rules may revert with module-specific errors for invalid mints.
    /// @param ctx Shared mint context.
    /// @param runtimeData Per-mint data for this rule, such as a proof or signature.
    /// @return output Rule effects applied by the controller engine.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData)
        external
        returns (NamespaceTypes.RuleOutput memory output);

    /// @notice Evaluate a renewal.
    /// @dev Rules may revert with module-specific errors for invalid renewals.
    /// @param ctx Shared renewal context.
    /// @param runtimeData Per-renewal data for this rule.
    /// @return output Rule effects applied by the controller engine.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData)
        external
        returns (NamespaceTypes.RuleOutput memory output);
}
