// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
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
    uint256 private constant _MAX_REGISTRY_PARENT_DEPTH = 128;

    struct ActivationData {
        address owner;
        IPermissionedRegistry registry;
        bytes32 parentNode;
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

    /// @notice Total number of activations created by this controller.
    uint256 public activationNonce;

    /// @notice Whether activation modules must be approved by the controller owner.
    bool public moduleApprovalRequired;

    /// @notice Canonical ENSv2 root registry used to validate activation registry parent chains.
    IRegistry public rootRegistry;

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

    function _checkCanonicalParentNode(IPermissionedRegistry registry, bytes32 parentNode) internal view {
        IRegistry root = rootRegistry;
        if (address(root) == address(0)) {
            revert RootRegistryNotConfigured();
        }

        bytes32 canonicalParentNode = _canonicalRegistryNode(registry, root, 0);
        if (canonicalParentNode != parentNode) {
            revert RegistryParentNodeMismatch(address(registry), canonicalParentNode, parentNode);
        }
    }

    function _checkDuration(bytes32 activationId, ActivationData storage activation, uint64 duration) internal view {
        if (duration < activation.minDuration || duration > activation.maxDuration) {
            revert DurationOutOfBounds(activationId, duration, activation.minDuration, activation.maxDuration);
        }
    }

    function _canonicalRegistryNode(IRegistry registry, IRegistry root, uint256 depth) private view returns (bytes32 node) {
        if (address(registry) == address(root)) {
            return bytes32(0);
        }
        if (depth > _MAX_REGISTRY_PARENT_DEPTH) {
            revert RegistryParentChainTooDeep(address(registry));
        }

        (IRegistry parent, string memory label) = registry.getParent();
        if (address(parent) == address(0)) {
            revert RegistryParentNotConfigured(address(registry));
        }

        NameCoder.assertLabelSize(label);
        IRegistry child = parent.getSubregistry(label);
        if (address(child) != address(registry)) {
            revert RegistryParentChildMismatch(address(registry), address(parent), label, address(child));
        }
        node = NameCoder.namehash(_canonicalRegistryNode(parent, root, depth + 1), keccak256(bytes(label)));
    }
}
