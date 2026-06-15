// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title IPostHookModule
/// @notice Optional hooks executed after ENSv2 registry writes.
interface IPostHookModule is IConfigurableModule {
    /// @notice Called after a successful subname mint.
    /// @param ctx Shared mint context.
    /// @param tokenId Token id returned by the ENSv2 registry.
    /// @param runtimeData Runtime hook data.
    function afterMint(NamespaceTypes.MintContext calldata ctx, uint256 tokenId, bytes calldata runtimeData) external;

    /// @notice Called after a successful subname renewal.
    /// @param ctx Shared renewal context.
    /// @param runtimeData Runtime hook data.
    function afterRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData) external;
}
