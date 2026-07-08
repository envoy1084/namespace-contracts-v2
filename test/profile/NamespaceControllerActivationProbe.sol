// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {IUniversalResolverV2} from "@ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

contract NamespaceControllerActivationProbe is NamespaceController {
    struct ActivationGasProfile {
        uint256 loadResolverAndValidateName;
        uint256 findExactRegistry;
        uint256 findParentRegistry;
        uint256 labelHashAndParentState;
        uint256 parentSubregistryCheck;
        uint256 namehashAndActivationKey;
        uint256 durationAndPaymentChecks;
        uint256 ownerAdminCheck;
        uint256 controllerRegistryRolesCheck;
        uint256 activationIdCheck;
        uint256 storeModuleLists;
        uint256 storeActivation;
        uint256 storeOwnerAndRegistries;
        uint256 storeNamespaceIdentity;
        uint256 storeNamespaceLabel;
        uint256 storeMintConfig;
        uint256 storeModuleRefs;
        uint256 emitActivationEvents;
        uint256 configureModules;
        uint256 measuredBodyTotal;
    }

    function activateProfile(bytes calldata name, NamespaceTypes.ActivationConfig calldata config)
        external
        nonReentrant
        returns (bytes32 activationId, ActivationGasProfile memory profile)
    {
        uint256 bodyStart = gasleft();
        uint256 sliceStart;

        sliceStart = gasleft();
        IUniversalResolverV2 resolver = universalResolver;
        if (address(resolver) == address(0)) revert UniversalResolverNotConfigured();
        if (NameCoder.countLabels(name, 0) == 0) revert InvalidNamespaceName(name);
        profile.loadResolverAndValidateName = sliceStart - gasleft();

        ResolvedNamespace memory resolved;
        IPermissionedRegistry.State memory state;

        sliceStart = gasleft();
        {
            IRegistry registry = resolver.findExactRegistry(name);
            if (address(registry) == address(0)) revert NamespaceRegistryNotFound(name);
            resolved.registry = IPermissionedRegistry(address(registry));
        }
        profile.findExactRegistry = sliceStart - gasleft();

        sliceStart = gasleft();
        {
            IRegistry parent = resolver.findParentRegistry(name);
            if (address(parent) == address(0)) revert NamespaceParentRegistryNotFound(name);
            resolved.parentRegistry = IPermissionedRegistry(address(parent));
        }
        profile.findParentRegistry = sliceStart - gasleft();

        sliceStart = gasleft();
        resolved.label = NameCoder.firstLabel(name);
        resolved.labelHash = _profileLabelHash(resolved.label);
        state = resolved.parentRegistry.getState(uint256(resolved.labelHash));
        if (state.status != IPermissionedRegistry.Status.REGISTERED) {
            revert NamespaceNotRegistered(name, state.status);
        }
        resolved.resource = state.resource;
        profile.labelHashAndParentState = sliceStart - gasleft();

        sliceStart = gasleft();
        {
            IRegistry currentRegistry = resolved.parentRegistry.getSubregistry(resolved.label);
            if (address(currentRegistry) != address(resolved.registry)) {
                revert NamespaceRegistryNotFound(name);
            }
        }
        profile.parentSubregistryCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        resolved.parentNode = NameCoder.namehash(name, 0);
        resolved.namespaceKey = keccak256(
            abi.encode(
                block.chainid,
                address(resolved.registry),
                resolved.parentNode,
                address(resolved.parentRegistry),
                resolved.resource
            )
        );
        profile.namehashAndActivationKey = sliceStart - gasleft();

        sliceStart = gasleft();
        if (config.maxDuration == 0 || config.minDuration > config.maxDuration) {
            revert InvalidDurationBounds(config.minDuration, config.maxDuration);
        }
        if (config.paymentModule.module != address(0)) {
            _checkModule(config.paymentModule.module, MODULE_KIND_PAYMENT);
        }
        profile.durationAndPaymentChecks = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkRegistryAdminAuthority(msg.sender, resolved.registry);
        profile.ownerAdminCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        if (!resolved.registry.hasRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(this))) {
            revert ControllerMissingRegistryRoles(address(resolved.registry), ROLE_REGISTRAR | ROLE_RENEW);
        }
        profile.controllerRegistryRolesCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        activationId = resolved.namespaceKey;
        if (activations[activationId].owner != address(0)) {
            revert NamespaceAlreadyActivated(resolved.namespaceKey, activationId);
        }
        profile.activationIdCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        _storeRuleList(config.rules);
        _storeModuleList(MODULE_KIND_POST_HOOK, config.postHooks);
        profile.storeModuleLists = sliceStart - gasleft();

        sliceStart = gasleft();
        _storeActivationProfile(activationId, resolved, config, profile);
        profile.storeActivation = sliceStart - gasleft();

        sliceStart = gasleft();
        emit ActivationCreated(activationId, msg.sender, address(resolved.registry), resolved.parentNode);
        emit ActivationStatusChanged(activationId, true);
        profile.emitActivationEvents = sliceStart - gasleft();

        sliceStart = gasleft();
        _configureRules(activationId, config.rules);
        if (config.paymentModule.module != address(0)) {
            _configureSingleModule(activationId, MODULE_KIND_PAYMENT, config.paymentModule);
        }
        _configureModules(activationId, config.postHooks);
        profile.configureModules = sliceStart - gasleft();

        profile.measuredBodyTotal = bodyStart - gasleft();
    }

    function _storeActivationProfile(
        bytes32 activationId,
        ResolvedNamespace memory resolved,
        NamespaceTypes.ActivationConfig calldata config,
        ActivationGasProfile memory profile
    ) private {
        uint256 sliceStart;
        ActivationData storage activation = activations[activationId];

        sliceStart = gasleft();
        activation.owner = msg.sender;
        activation.registry = resolved.registry;
        activation.parentRegistry = resolved.parentRegistry;
        profile.storeOwnerAndRegistries = sliceStart - gasleft();

        sliceStart = gasleft();
        activation.parentNode = resolved.parentNode;
        activation.namespaceResource = resolved.resource;
        profile.storeNamespaceIdentity = sliceStart - gasleft();

        sliceStart = gasleft();
        activation.namespaceLabel = resolved.label;
        profile.storeNamespaceLabel = sliceStart - gasleft();

        sliceStart = gasleft();
        activation.resolver = config.resolver;
        activation.buyerRoleBitmap = config.buyerRoleBitmap;
        activation.minDuration = config.minDuration;
        activation.maxDuration = config.maxDuration;
        activation.active = true;
        profile.storeMintConfig = sliceStart - gasleft();

        sliceStart = gasleft();
        activation.ruleCount = 0;
        activation.firstRulePhase = 0;
        activation.postHookCount = 0;
        activation.paymentModule = config.paymentModule.module;
        activation.rules = address(0);
        activation.postHooks = address(0);
        profile.storeModuleRefs = sliceStart - gasleft();
    }

    function _profileLabelHash(string memory label) private pure returns (bytes32 hash) {
        bytes memory labelBytes = bytes(label);
        assembly ("memory-safe") {
            hash := keccak256(add(labelBytes, 0x20), mload(labelBytes))
        }
    }
}
