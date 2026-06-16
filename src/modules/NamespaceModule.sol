// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";

/// @title NamespaceModule
/// @notice Base contract for activation-scoped Namespace modules.
abstract contract NamespaceModule is IConfigurableModule, Ownable, Initializable, UUPSUpgradeable {
    /// @notice Namespace controller allowed to configure this module.
    address public controller;

    /// @notice Caller is not the configured Namespace controller.
    error NotController(address caller);
    /// @notice Controller address is zero.
    error ZeroController();

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the module proxy.
    /// @param controller_ Namespace controller address.
    /// @param owner_ Owner allowed to upgrade the module implementation.
    function initialize(address controller_, address owner_) external initializer {
        if (controller_ == address(0)) {
            revert ZeroController();
        }
        controller = controller_;
        _initializeOwner(owner_);
    }

    /// @notice Restricts functions to the Namespace controller.
    modifier onlyController() {
        _onlyController();
        _;
    }

    function _onlyController() internal view {
        if (msg.sender != controller) {
            revert NotController(msg.sender);
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
