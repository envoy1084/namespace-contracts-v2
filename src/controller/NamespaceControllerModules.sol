// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceControllerStorage} from "src/controller/NamespaceControllerStorage.sol";

/// @title NamespaceControllerModules
/// @notice Module approval, compact module-list storage, and module config helpers.
abstract contract NamespaceControllerModules is NamespaceControllerStorage {
    /// @inheritdoc INamespaceController
    function updateModuleConfig(bytes32 activationId, bytes32 kind, uint256 index, bytes calldata configData) external {
        _checkKnownModuleKind(kind);

        ActivationData storage activation = _requireActivation(activationId);
        _checkActivationOwner(activationId, activation);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);

        address module = _moduleAt(activation, activationId, kind, index);
        _checkModule(module, kind);
        emit ModuleConfigUpdated(activationId, module, kind, index);
        IConfigurableModule(module).configure(activationId, configData);
    }

    /// @inheritdoc INamespaceController
    function setModuleApprovalRequired(bool required) external onlyOwner {
        moduleApprovalRequired = required;
        emit ModuleApprovalRequiredSet(required);
    }

    /// @inheritdoc INamespaceController
    function setModuleApproval(address module, bool approved) external onlyOwner {
        if (module == address(0)) {
            revert ZeroModule(bytes32(0));
        }
        _setModuleApproval(MODULE_KIND_RULE, module, approved);
        _setModuleApproval(MODULE_KIND_PAYMENT, module, approved);
        _setModuleApproval(MODULE_KIND_POST_HOOK, module, approved);
    }

    /// @inheritdoc INamespaceController
    function setModuleApproval(bytes32 kind, address module, bool approved) external onlyOwner {
        _checkKnownModuleKind(kind);
        if (module == address(0)) {
            revert ZeroModule(kind);
        }
        _setModuleApproval(kind, module, approved);
    }

    /// @notice Return configured rule modules for an activation.
    function getRules(bytes32 activationId) external view returns (address[] memory rules) {
        ActivationData storage activation = _requireActivation(activationId);
        uint256 length = activation.ruleCount;
        rules = new address[](length);
        if (length == 0) return rules;
        if (length == 1) {
            rules[0] = activation.rules;
            return rules;
        }
        bytes memory packedRules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            rules[i] = _ruleAt(packedRules, i).module;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Return configured post-mint hooks for an activation.
    function getPostHooks(bytes32 activationId) external view returns (address[] memory postHooks) {
        ActivationData storage activation = _requireActivation(activationId);
        bytes memory packedModules = _readModuleList(activation.postHooks, activation.postHookCount);
        postHooks = _unpackModules(packedModules);
    }

    function _storeModuleList(bytes32 kind, NamespaceTypes.ModuleConfig[] calldata configs)
        internal
        returns (address moduleData, uint8 count)
    {
        uint256 length = configs.length;
        if (length > type(uint8).max) revert ModuleListTooLong(kind, length);
        // forge-lint: disable-next-line(unsafe-typecast)
        count = uint8(length);
        if (length == 0) return (address(0), count);
        if (length == 1) {
            moduleData = configs[0].module;
            _checkModule(moduleData, kind);
            return (moduleData, count);
        }

        bytes memory modules = new bytes(length * 20);
        for (uint256 i; i < length;) {
            NamespaceTypes.ModuleConfig calldata config = configs[i];
            _checkModule(config.module, kind);
            _packModule(modules, i, config.module);
            unchecked {
                ++i;
            }
        }
        moduleData = SSTORE2.write(modules);
    }

    function _storeRuleList(NamespaceTypes.RuleConfig[] calldata configs)
        internal
        returns (address ruleData, uint8 count, uint8 firstRulePhase)
    {
        uint256 length = configs.length;
        if (length > type(uint8).max) revert ModuleListTooLong(MODULE_KIND_RULE, length);
        // forge-lint: disable-next-line(unsafe-typecast)
        count = uint8(length);
        if (length == 0) return (address(0), count, firstRulePhase);

        NamespaceTypes.RulePhase previousPhase = configs[0].phase;
        firstRulePhase = uint8(previousPhase);
        if (length == 1) {
            ruleData = configs[0].module;
            _checkModule(ruleData, MODULE_KIND_RULE);
            return (ruleData, count, firstRulePhase);
        }

        bytes memory rules = new bytes(length * 21);
        for (uint256 i; i < length;) {
            NamespaceTypes.RuleConfig calldata config = configs[i];
            if (uint8(config.phase) < uint8(previousPhase)) {
                revert RulePhaseOrderInvalid(i, previousPhase, config.phase);
            }
            previousPhase = config.phase;
            _checkModule(config.module, MODULE_KIND_RULE);
            _packRule(rules, i, config.module, config.phase);
            unchecked {
                ++i;
            }
        }
        ruleData = SSTORE2.write(rules);
    }

    function _configureModules(bytes32 activationId, NamespaceTypes.ModuleConfig[] calldata configs) internal {
        uint256 length = configs.length;
        for (uint256 i; i < length;) {
            NamespaceTypes.ModuleConfig calldata config = configs[i];
            IConfigurableModule(config.module).configure(activationId, config.configData);
            unchecked {
                ++i;
            }
        }
    }

    function _configureRules(bytes32 activationId, NamespaceTypes.RuleConfig[] calldata configs) internal {
        uint256 length = configs.length;
        for (uint256 i; i < length;) {
            NamespaceTypes.RuleConfig calldata config = configs[i];
            IConfigurableModule(config.module).configure(activationId, config.configData);
            unchecked {
                ++i;
            }
        }
    }

    function _configureSingleModule(bytes32 activationId, bytes32 kind, NamespaceTypes.ModuleConfig calldata config)
        internal
    {
        _checkModule(config.module, kind);
        IConfigurableModule(config.module).configure(activationId, config.configData);
    }

    function _checkModule(address module, bytes32 kind) internal view {
        if (module == address(0)) revert ZeroModule(kind);
        if (moduleApprovalRequired && !approvedModules[kind][module]) {
            revert UnapprovedModule(module, kind);
        }
    }

    function _moduleAt(ActivationData storage activation, bytes32 activationId, bytes32 kind, uint256 index)
        internal
        view
        returns (address module)
    {
        if (kind == MODULE_KIND_RULE) {
            if (index >= activation.ruleCount) {
                revert ModuleIndexOutOfBounds(activationId, kind, index, activation.ruleCount);
            }
            if (activation.ruleCount == 1) return activation.rules;
            return _ruleAt(SSTORE2.read(activation.rules), index).module;
        }
        if (kind == MODULE_KIND_PAYMENT) {
            uint256 paymentLength = activation.paymentModule == address(0) ? 0 : 1;
            if (index >= paymentLength) {
                revert ModuleIndexOutOfBounds(activationId, kind, index, paymentLength);
            }
            return activation.paymentModule;
        }

        uint8 moduleCount = activation.postHookCount;
        if (index >= moduleCount) revert ModuleIndexOutOfBounds(activationId, kind, index, moduleCount);
        if (moduleCount == 1) return activation.postHooks;
        module = _moduleAt(SSTORE2.read(activation.postHooks), index);
    }

    function _readModuleList(address moduleData, uint256 length) internal view returns (bytes memory modules) {
        if (length == 0) return new bytes(0);
        if (length == 1) {
            modules = new bytes(20);
            _packModule(modules, 0, moduleData);
            return modules;
        }
        modules = SSTORE2.read(moduleData);
    }

    function _checkRuntimeDataLengths(
        ActivationData storage activation,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) internal view {
        uint256 ruleLength = activation.ruleCount;
        if (runtimeData.ruleData.length != ruleLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_RULE, ruleLength, runtimeData.ruleData.length);
        }
        uint256 postHookLength = activation.postHookCount;
        if (runtimeData.postHookData.length != postHookLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_POST_HOOK, postHookLength, runtimeData.postHookData.length);
        }
    }

    function _checkKnownModuleKind(bytes32 kind) internal pure {
        if (kind != MODULE_KIND_RULE && kind != MODULE_KIND_PAYMENT && kind != MODULE_KIND_POST_HOOK) {
            revert ZeroModule(kind);
        }
    }

    function _setModuleApproval(bytes32 kind, address module, bool approved) private {
        approvedModules[kind][module] = approved;
        emit ModuleApprovalSet(kind, module, approved);
    }

    function _packModule(bytes memory modules, uint256 index, address module) private pure {
        uint256 offset = 32 + index * 20;
        assembly ("memory-safe") {
            let word := mload(add(modules, offset))
            mstore(add(modules, offset), or(shl(96, module), and(word, 0xffffffffffffffffffffffff)))
        }
    }

    function _packRule(bytes memory rules, uint256 index, address module, NamespaceTypes.RulePhase phase) private pure {
        uint256 offset = 32 + index * 21;
        assembly ("memory-safe") {
            let ptr := add(rules, offset)
            let word := mload(ptr)
            mstore(ptr, or(shl(96, module), and(word, 0xffffffffffffffffffffffff)))
            mstore8(add(ptr, 20), phase)
        }
    }

    function _moduleAt(bytes memory modules, uint256 index) internal pure returns (address module) {
        uint256 offset = 32 + index * 20;
        assembly ("memory-safe") {
            module := shr(96, mload(add(modules, offset)))
        }
    }

    function _ruleAt(bytes memory rules, uint256 index) internal pure returns (RuleRef memory rule) {
        uint256 offset = 32 + index * 21;
        address module;
        uint8 phase;
        assembly ("memory-safe") {
            let ptr := add(rules, offset)
            module := shr(96, mload(ptr))
            phase := shr(248, mload(add(ptr, 20)))
        }
        rule = RuleRef({module: module, phase: NamespaceTypes.RulePhase(phase)});
    }

    function _unpackModules(bytes memory packedModules) private pure returns (address[] memory modules) {
        uint256 length = packedModules.length / 20;
        modules = new address[](length);
        for (uint256 i; i < length;) {
            modules[i] = _moduleAt(packedModules, i);
            unchecked {
                ++i;
            }
        }
    }
}
