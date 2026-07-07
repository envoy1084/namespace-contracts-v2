// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

    struct ActivationData {
        address owner;
        IPermissionedRegistry registry;
        bytes32 parentNode;
        address resolver;
        uint256 buyerRoleBitmap;
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
        if (!registry.hasRootRoles(ROLE_REGISTRAR_ADMIN, account)) {
            revert UnauthorizedActivationOwner(account, address(registry));
        }
    }
}
