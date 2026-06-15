// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IProcessorModule} from "src/interfaces/IProcessorModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title NoopProcessor
/// @notice Processor module for activations where payment collection already settles funds.
contract NoopProcessor is NamespaceModule, IProcessorModule {
    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Accept activation configuration without storing any processor state.
    function configure(bytes32, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }

    /// @inheritdoc IProcessorModule
    function processMint(NamespaceTypes.MintContext calldata, NamespaceTypes.Price calldata, bytes calldata)
        external
        view
        onlyController
    {
        // Intentionally no-op.
    }

    /// @inheritdoc IProcessorModule
    function processRenew(NamespaceTypes.RenewContext calldata, NamespaceTypes.Price calldata, bytes calldata)
        external
        view
        onlyController
    {
        // Intentionally no-op.
    }
}
