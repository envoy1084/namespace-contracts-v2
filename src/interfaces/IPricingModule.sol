// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title IPricingModule
/// @notice Sequential price composition for Namespace mints and renewals.
interface IPricingModule is IConfigurableModule {
    /// @notice Compose a mint price.
    /// @param ctx Shared mint context.
    /// @param currentPrice Price returned by previous pricing modules.
    /// @param runtimeData Per-mint pricing data.
    /// @return price Updated price.
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata runtimeData
    ) external view returns (NamespaceTypes.Price memory price);

    /// @notice Compose a renewal price.
    /// @param ctx Shared renewal context.
    /// @param currentPrice Price returned by previous pricing modules.
    /// @param runtimeData Per-renewal pricing data.
    /// @return price Updated price.
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata runtimeData
    ) external view returns (NamespaceTypes.Price memory price);
}
