// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title PausePolicy
/// @notice Lets the activation owner pause minting and renewals for a namespace activation.
contract PausePolicy is NamespaceModule, IPolicyModule {
    mapping(bytes32 activationId => bool paused) public paused;

    event PauseStatusChanged(bytes32 indexed activationId, bool paused);

    error ActivationPaused(bytes32 activationId);
    error NotActivationOwner(bytes32 activationId, address caller, address owner);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Accept activation configuration without storing policy state.
    function configure(bytes32, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }

    /// @notice Pause or unpause an activation.
    /// @dev The activation owner is the verified parent namespace controller in `NamespaceController`.
    function setPaused(bytes32 activationId, bool paused_) external {
        NamespaceTypes.Activation memory activation = INamespaceController(CONTROLLER).getActivation(activationId);
        if (msg.sender != activation.owner) {
            revert NotActivationOwner(activationId, msg.sender, activation.owner);
        }
        paused[activationId] = paused_;
        emit PauseStatusChanged(activationId, paused_);
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata) external view {
        _checkPaused(ctx.activationId);
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata) external view {
        _checkPaused(ctx.activationId);
    }

    function _checkPaused(bytes32 activationId) private view {
        if (paused[activationId]) {
            revert ActivationPaused(activationId);
        }
    }
}
