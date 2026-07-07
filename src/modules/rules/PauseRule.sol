// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RegistryRolesLib} from "@ensv2/registry/libraries/RegistryRolesLib.sol";

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title PauseRule
/// @notice Lets an activation owner pause minting and renewals for a namespace activation.
contract PauseRule is NamespaceRule {
    mapping(bytes32 activationId => bool paused) public paused;

    event PauseStatusChanged(bytes32 indexed activationId, bool paused);

    error ActivationPaused(bytes32 activationId);
    error NotActivationOwner(bytes32 activationId, address caller, address owner);

    /// @notice Accept activation configuration without storing rule state.
    function configure(bytes32, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }

    /// @notice Pause or unpause an activation.
    function setPaused(bytes32 activationId, bool paused_) external {
        NamespaceTypes.Activation memory activation = INamespaceController(controller).getActivation(activationId);
        if (msg.sender != activation.owner) {
            revert NotActivationOwner(activationId, msg.sender, activation.owner);
        }
        uint256 requiredRoles = RegistryRolesLib.ROLE_REGISTRAR_ADMIN | RegistryRolesLib.ROLE_RENEW_ADMIN;
        if (!activation.registry.hasRootRoles(requiredRoles, msg.sender)) {
            revert INamespaceController.UnauthorizedActivationOwner(msg.sender, address(activation.registry));
        }
        paused[activationId] = paused_;
        emit PauseStatusChanged(activationId, paused_);
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        _checkPaused(ctx.activationId);
        output = _pass();
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        _checkPaused(ctx.activationId);
        output = _pass();
    }

    function _checkPaused(bytes32 activationId) private view {
        if (paused[activationId]) {
            revert ActivationPaused(activationId);
        }
    }
}
