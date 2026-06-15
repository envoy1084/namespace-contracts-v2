// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title IPaymentModule
/// @notice Collects funds for Namespace mints and renewals.
interface IPaymentModule is IConfigurableModule {
    /// @notice Collect payment for a mint.
    /// @param ctx Shared mint context.
    /// @param price Final composed price.
    /// @param runtimeData Runtime payment data, e.g. permit payload.
    function collectMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata price,
        bytes calldata runtimeData
    ) external payable;

    /// @notice Collect payment for a renewal.
    /// @param ctx Shared renewal context.
    /// @param price Final composed price.
    /// @param runtimeData Runtime payment data.
    function collectRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata price,
        bytes calldata runtimeData
    ) external payable;
}
