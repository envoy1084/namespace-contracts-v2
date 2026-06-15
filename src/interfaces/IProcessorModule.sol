// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title IProcessorModule
/// @notice Handles post-collection accounting or distribution of collected funds.
interface IProcessorModule is IConfigurableModule {
    /// @notice Process payment after mint funds are collected.
    /// @param ctx Shared mint context.
    /// @param price Final composed price.
    /// @param runtimeData Runtime processor data, e.g. referrer.
    function processMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata price,
        bytes calldata runtimeData
    ) external;

    /// @notice Process payment after renewal funds are collected.
    /// @param ctx Shared renewal context.
    /// @param price Final composed price.
    /// @param runtimeData Runtime processor data.
    function processRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata price,
        bytes calldata runtimeData
    ) external;
}
