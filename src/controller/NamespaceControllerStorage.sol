// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {IUniversalResolverV2} from "@ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title NamespaceControllerStorage
/// @notice Shared storage, constants, and errors for the Namespace controller inheritance tree.
abstract contract NamespaceControllerStorage is
    INamespaceController,
    Ownable,
    Initializable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    /// @notice Module kind emitted for rule configuration.
    bytes32 public constant MODULE_KIND_RULE = keccak256("RULE");
    /// @notice Module kind emitted for payment configuration.
    bytes32 public constant MODULE_KIND_PAYMENT = keccak256("PAYMENT");
    /// @notice Module kind emitted for post-hook configuration.
    bytes32 public constant MODULE_KIND_POST_HOOK = keccak256("POST_HOOK");

    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant ROLE_REGISTRAR = 1 << 0;
    uint256 internal constant ROLE_REGISTRAR_ADMIN = ROLE_REGISTRAR << 128;
    uint256 internal constant ROLE_RENEW = 1 << 16;
    uint256 internal constant ROLE_RENEW_ADMIN = ROLE_RENEW << 128;

    struct ActivationData {
        address owner;
        IPermissionedRegistry registry;
        IPermissionedRegistry parentRegistry;
        bytes32 parentNode;
        uint256 namespaceResource;
        string namespaceLabel;
        address resolver;
        uint256 buyerRoleBitmap;
        uint64 minDuration;
        uint64 maxDuration;
        bool active;
        uint8 ruleCount;
        uint8 firstRulePhase;
        uint8 postHookCount;
        address paymentModule;
        address rules;
        address postHooks;
    }

    struct RuleRef {
        address module;
        NamespaceTypes.RulePhase phase;
    }

    struct EvaluationState {
        uint256 amount;
        uint256 flags;
        address token;
        uint256 status;
    }

    struct ResolvedNamespace {
        IPermissionedRegistry registry;
        IPermissionedRegistry parentRegistry;
        bytes32 namespaceKey;
        bytes32 parentNode;
        bytes32 labelHash;
        uint256 resource;
        string label;
    }

    /// @notice Whether activation modules must be approved by the controller owner.
    bool public moduleApprovalRequired;

    /// @notice Root registry reported by the configured ENSv2 UniversalResolver.
    IRegistry public rootRegistry;

    /// @notice ENSv2 UniversalResolver used to discover canonical namespace registries.
    IUniversalResolverV2 public universalResolver;

    mapping(bytes32 activationId => ActivationData activation) internal activations;
    mapping(address registry => mapping(bytes32 labelHash => bytes32 activationId)) internal labelActivations;
    mapping(bytes32 kind => mapping(address module => bool approved)) public approvedModules;

    function _requireActivation(bytes32 activationId) internal view returns (ActivationData storage activation) {
        activation = activations[activationId];
        if (activation.owner == address(0)) {
            revert ActivationNotFound(activationId);
        }
    }

    function _checkActivationOwner(bytes32 activationId, ActivationData storage activation) internal view {
        if (msg.sender != activation.owner) {
            revert NotActivationOwner(activationId, msg.sender);
        }
    }

    function _checkRegistryAdminAuthority(address account, IPermissionedRegistry registry) internal view {
        if (!registry.hasRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, account)) {
            revert UnauthorizedActivationOwner(account, address(registry));
        }
    }

    function _checkDuration(bytes32 activationId, ActivationData storage activation, uint64 duration) internal view {
        if (duration < activation.minDuration || duration > activation.maxDuration) {
            revert DurationOutOfBounds(activationId, duration, activation.minDuration, activation.maxDuration);
        }
    }

    function _resolveNamespace(bytes calldata name) internal view returns (ResolvedNamespace memory resolved) {
        IUniversalResolverV2 resolver = universalResolver;
        if (address(resolver) == address(0)) revert UniversalResolverNotConfigured();
        if (NameCoder.countLabels(name, 0) == 0) revert InvalidNamespaceName(name);

        IRegistry registry = resolver.findExactRegistry(name);
        if (address(registry) == address(0)) revert NamespaceRegistryNotFound(name);

        IRegistry parent = resolver.findParentRegistry(name);
        if (address(parent) == address(0)) revert NamespaceParentRegistryNotFound(name);

        string memory label = NameCoder.firstLabel(name);
        bytes32 labelHash = _labelHash(label);
        IPermissionedRegistry parentRegistry = IPermissionedRegistry(address(parent));
        IPermissionedRegistry.State memory state = parentRegistry.getState(uint256(labelHash));
        if (state.status != IPermissionedRegistry.Status.REGISTERED) {
            revert NamespaceNotRegistered(name, state.status);
        }
        IRegistry currentRegistry = parentRegistry.getSubregistry(label);
        if (address(currentRegistry) != address(registry)) {
            revert NamespaceRegistryNotFound(name);
        }

        bytes32 parentNode = NameCoder.namehash(name, 0);
        resolved = ResolvedNamespace({
            registry: IPermissionedRegistry(address(registry)),
            parentRegistry: parentRegistry,
            namespaceKey: keccak256(
                abi.encode(block.chainid, address(registry), parentNode, address(parentRegistry), state.resource)
            ),
            parentNode: parentNode,
            labelHash: labelHash,
            resource: state.resource,
            label: label
        });
    }

    function _checkNamespaceCurrent(bytes32 activationId, ActivationData storage activation) internal view {
        IPermissionedRegistry.State memory state =
            activation.parentRegistry.getState(uint256(_labelHash(activation.namespaceLabel)));
        if (state.status != IPermissionedRegistry.Status.REGISTERED) {
            revert NamespaceActivationUnavailable(activationId, state.status);
        }
        if (state.resource != activation.namespaceResource) {
            revert NamespaceActivationStale(activationId, activation.namespaceResource, state.resource);
        }
        IRegistry currentRegistry = activation.parentRegistry.getSubregistry(activation.namespaceLabel);
        if (address(currentRegistry) != address(activation.registry)) {
            revert NamespaceRegistryChanged(activationId, address(activation.registry), address(currentRegistry));
        }
    }

    function _labelHash(string memory label) private pure returns (bytes32 hash) {
        bytes memory labelBytes = bytes(label);
        assembly ("memory-safe") {
            hash := keccak256(add(labelBytes, 0x20), mload(labelBytes))
        }
    }
}
