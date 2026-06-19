// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceControllerModules} from "src/controller/NamespaceControllerModules.sol";

/// @title NamespaceControllerLifecycle
/// @notice Activation lifecycle and controller administration.
abstract contract NamespaceControllerLifecycle is NamespaceControllerModules {
    /// @notice Initialize the controller proxy.
    /// @param initialOwner Owner of controller-level administration.
    function initialize(address initialOwner) external initializer {
        _initializeOwner(initialOwner);
        moduleApprovalRequired = true;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @inheritdoc INamespaceController
    function activate(NamespaceTypes.ActivationConfig calldata config)
        external
        nonReentrant
        returns (bytes32 activationId)
    {
        _checkActivationPreconditions(config);

        uint256 nonce = ++activationNonce;
        activationId =
            keccak256(abi.encode(block.chainid, address(config.registry), config.parentNode, msg.sender, nonce));

        (address rules, uint8 ruleCount, uint8 firstRulePhase) = _storeRuleList(config.rules);
        (address postHooks, uint8 postHookCount) = _storeModuleList(MODULE_KIND_POST_HOOK, config.postHooks);

        _storeActivation(activationId, config, rules, ruleCount, firstRulePhase, postHooks, postHookCount);

        emit ActivationCreated(activationId, msg.sender, address(config.registry), config.parentNode);
        emit ActivationStatusChanged(activationId, true);

        _configureRules(activationId, config.rules);
        if (config.paymentModule.module != address(0)) {
            _configureSingleModule(activationId, MODULE_KIND_PAYMENT, config.paymentModule);
        }
        _configureModules(activationId, config.postHooks);
    }

    /// @inheritdoc INamespaceController
    function setActivationStatus(bytes32 activationId, bool active) external {
        ActivationData storage activation = _requireActivation(activationId);
        _checkActivationOwner(activationId, activation);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        activation.active = active;
        emit ActivationStatusChanged(activationId, active);
    }

    /// @inheritdoc INamespaceController
    function transferActivationOwnership(bytes32 activationId, address newOwner) external {
        if (newOwner == address(0)) revert ZeroActivationOwner();

        ActivationData storage activation = _requireActivation(activationId);
        _checkActivationOwner(activationId, activation);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        _checkRegistryAdminAuthority(newOwner, activation.registry);

        address previousOwner = activation.owner;
        activation.owner = newOwner;
        emit ActivationOwnershipTransferred(activationId, previousOwner, newOwner);
    }

    /// @inheritdoc INamespaceController
    function getActivation(bytes32 activationId) external view returns (NamespaceTypes.Activation memory activation) {
        ActivationData storage stored = _requireActivation(activationId);
        activation = NamespaceTypes.Activation({
            owner: stored.owner,
            registry: stored.registry,
            parentNode: stored.parentNode,
            resolver: stored.resolver,
            buyerRoleBitmap: stored.buyerRoleBitmap,
            active: stored.active,
            paymentModule: stored.paymentModule
        });
    }

    function _storeActivation(
        bytes32 activationId,
        NamespaceTypes.ActivationConfig calldata config,
        address rules,
        uint8 ruleCount,
        uint8 firstRulePhase,
        address postHooks,
        uint8 postHookCount
    ) private {
        ActivationData storage activation = activations[activationId];
        activation.owner = msg.sender;
        activation.registry = config.registry;
        activation.parentNode = config.parentNode;
        activation.resolver = config.resolver;
        activation.buyerRoleBitmap = config.buyerRoleBitmap;
        activation.active = true;
        activation.ruleCount = ruleCount;
        activation.firstRulePhase = firstRulePhase;
        activation.postHookCount = postHookCount;
        activation.paymentModule = config.paymentModule.module;
        activation.rules = rules;
        activation.postHooks = postHooks;
    }

    function _checkActivationPreconditions(NamespaceTypes.ActivationConfig calldata config) private view {
        if (address(config.registry) == address(0)) revert ZeroRegistry();
        if (config.paymentModule.module != address(0)) {
            _checkModule(config.paymentModule.module, MODULE_KIND_PAYMENT);
        }
        _checkRegistryAdminAuthority(msg.sender, config.registry);
        if (!config.registry.hasRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(this))) {
            revert ControllerMissingRegistryRoles(address(config.registry), ROLE_REGISTRAR | ROLE_RENEW);
        }
    }
}
