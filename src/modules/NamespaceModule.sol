// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";

/// @title NamespaceModule
/// @notice Base contract for activation-scoped Namespace modules.
abstract contract NamespaceModule is IConfigurableModule {
    /// @notice Namespace controller allowed to configure this module.
    address public immutable CONTROLLER;

    /// @notice Caller is not the configured Namespace controller.
    error NotController(address caller);

    /// @param controller_ Namespace controller address.
    constructor(address controller_) {
        CONTROLLER = controller_;
    }

    /// @notice Restricts functions to the Namespace controller.
    modifier onlyController() {
        if (msg.sender != CONTROLLER) {
            revert NotController(msg.sender);
        }
        _;
    }
}
