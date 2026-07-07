// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title INamespaceController
/// @notice Main entry point for activation-based Namespace subname minting.
interface INamespaceController {
    error ActivationNotFound(bytes32 activationId);
    error ActivationNotActive(bytes32 activationId);
    error NotActivationOwner(bytes32 activationId, address caller);
    error ZeroModule(bytes32 kind);
    error UnapprovedModule(address module, bytes32 kind);
    error ZeroRegistry();
    error ZeroActivationOwner();
    error UnauthorizedActivationOwner(address caller, address registry);
    error ControllerMissingRegistryRoles(address registry, uint256 requiredRoles);
    error ZeroDuration();
    error RuntimeDataLengthMismatch(bytes32 kind, uint256 expected, uint256 actual);
    error ModuleIndexOutOfBounds(bytes32 activationId, bytes32 kind, uint256 index, uint256 length);
    error ModuleListTooLong(bytes32 kind, uint256 length);
    error RulePhaseOrderInvalid(uint256 index, NamespaceTypes.RulePhase previous, NamespaceTypes.RulePhase current);
    error RuleBlocked(bytes32 activationId, address rule, uint256 index);
    error RequiredRuleFlagsMissing(bytes32 activationId, address rule, uint256 index, uint256 required, uint256 actual);
    error RulePaymentTokenMismatch(address expected, address actual);
    error InvalidRuleBps(address rule, uint16 bps);
    error RuleOperationNotAllowed(
        bytes32 activationId,
        address rule,
        uint256 index,
        NamespaceTypes.RulePhase phase,
        NamespaceTypes.PriceOp operation
    );
    error RuleBasePriceAlreadySet(bytes32 activationId, address rule, uint256 index);
    error RulePriceAlreadyOverridden(bytes32 activationId, address rule, uint256 index);
    error RulePriceOperationBeforePrice(
        bytes32 activationId, address rule, uint256 index, NamespaceTypes.PriceOp operation
    );
    error LabelNotRenewable(string label, IPermissionedRegistry.Status status);

    /// @notice Emitted when a namespace activation is created.
    event ActivationCreated(
        bytes32 indexed activationId, address indexed owner, address indexed registry, bytes32 parentNode
    );

    /// @notice Emitted when an activation is enabled or disabled.
    event ActivationStatusChanged(bytes32 indexed activationId, bool active);

    /// @notice Emitted when activation ownership is transferred.
    event ActivationOwnershipTransferred(
        bytes32 indexed activationId, address indexed previousOwner, address indexed newOwner
    );

    /// @notice Emitted after an existing activation module receives updated config.
    event ModuleConfigUpdated(
        bytes32 indexed activationId, address indexed module, bytes32 indexed kind, uint256 index
    );

    /// @notice Emitted when module approval enforcement is enabled or disabled.
    event ModuleApprovalRequiredSet(bool required);

    /// @notice Emitted when a module approval status changes.
    event ModuleApprovalSet(bytes32 indexed kind, address indexed module, bool approved);

    /// @notice Emitted after a subname is minted.
    event SubnameMinted(
        bytes32 indexed activationId,
        bytes32 indexed labelHash,
        string label,
        address indexed owner,
        uint256 tokenId,
        address paymentToken,
        uint256 amount
    );

    /// @notice Emitted after a subname is renewed.
    event SubnameRenewed(
        bytes32 indexed activationId,
        bytes32 indexed labelHash,
        string label,
        uint256 tokenId,
        uint64 newExpiry,
        address paymentToken,
        uint256 amount
    );

    /// @notice Create and configure a namespace activation.
    /// @param config Activation configuration and module config payloads.
    /// @return activationId Created activation id.
    function activate(NamespaceTypes.ActivationConfig calldata config) external returns (bytes32 activationId);

    /// @notice Enable or disable an activation.
    /// @param activationId Activation id.
    /// @param active New active status.
    function setActivationStatus(bytes32 activationId, bool active) external;

    /// @notice Transfer activation ownership to another registry admin.
    /// @param activationId Activation id.
    /// @param newOwner New activation owner.
    function transferActivationOwnership(bytes32 activationId, address newOwner) external;

    /// @notice Update config for an existing module attached to an activation.
    /// @dev For payment modules, pass `index == 0`.
    /// @param activationId Activation id.
    /// @param kind Module kind, such as `MODULE_KIND_RULE`.
    /// @param index Module index in that kind's activation module list.
    /// @param configData New ABI-encoded module config.
    function updateModuleConfig(bytes32 activationId, bytes32 kind, uint256 index, bytes calldata configData) external;

    /// @notice Enable or disable controller-level module approval enforcement.
    /// @param required Whether activations must use approved module contracts.
    function setModuleApprovalRequired(bool required) external;

    /// @notice Approve or revoke a module contract for every module kind.
    /// @param module Module contract address.
    /// @param approved Whether the module is approved.
    function setModuleApproval(address module, bool approved) external;

    /// @notice Approve or revoke a module contract for one module kind.
    /// @param kind Module kind, such as `MODULE_KIND_RULE`.
    /// @param module Module contract address.
    /// @param approved Whether the module is approved.
    function setModuleApproval(bytes32 kind, address module, bool approved) external;

    /// @notice Mint a subname through a stored activation.
    /// @param activationId Activation id.
    /// @param label Direct label to register.
    /// @param duration Registration duration in seconds.
    /// @param runtimeData Per-module runtime data.
    /// @return tokenId Token id returned by the ENSv2 registry.
    function mint(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable returns (uint256 tokenId);

    /// @notice Renew a subname through a stored activation.
    /// @param activationId Activation id.
    /// @param label Direct label to renew.
    /// @param duration Renewal extension in seconds.
    /// @param runtimeData Per-module runtime data.
    /// @return newExpiry New expiry written to the ENSv2 registry.
    function renew(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable returns (uint64 newExpiry);

    /// @notice Read public activation metadata.
    /// @param activationId Activation id.
    /// @return activation Public activation metadata.
    function getActivation(bytes32 activationId) external view returns (NamespaceTypes.Activation memory activation);

    /// @notice Return configured rule modules for an activation.
    /// @param activationId Activation id.
    /// @return rules Ordered rule module addresses.
    function getRules(bytes32 activationId) external view returns (address[] memory rules);
}
