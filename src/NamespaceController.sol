// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {IProcessorModule} from "src/interfaces/IProcessorModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title NamespaceController
/// @notice Activation-based controller for minting ENSv2 subnames through official registries.
/// @dev The controller stores sale activations, delegates checks/pricing/payment/hooks to modules,
///      and writes ownership to an ENSv2 `IPermissionedRegistry`.
contract NamespaceController is INamespaceController, Ownable, ReentrancyGuard {
    /// @notice Module kind emitted for policy configuration.
    bytes32 public constant MODULE_KIND_POLICY = keccak256("POLICY");
    /// @notice Module kind emitted for pricing configuration.
    bytes32 public constant MODULE_KIND_PRICING = keccak256("PRICING");
    /// @notice Module kind emitted for payment configuration.
    bytes32 public constant MODULE_KIND_PAYMENT = keccak256("PAYMENT");
    /// @notice Module kind emitted for processor configuration.
    bytes32 public constant MODULE_KIND_PROCESSOR = keccak256("PROCESSOR");
    /// @notice Module kind emitted for post-hook configuration.
    bytes32 public constant MODULE_KIND_POST_HOOK = keccak256("POST_HOOK");

    uint256 private constant _ROLE_REGISTRAR = 1 << 0;
    uint256 private constant _ROLE_REGISTRAR_ADMIN = _ROLE_REGISTRAR << 128;
    uint256 private constant _ROLE_RENEW = 1 << 16;

    struct ActivationData {
        address owner;
        IPermissionedRegistry registry;
        bytes32 parentNode;
        address resolver;
        uint256 buyerRoleBitmap;
        bool active;
        address paymentModule;
        address processor;
        address[] policies;
        address[] pricingModules;
        address[] postHooks;
    }

    /// @notice Total number of activations created by this controller.
    uint256 public activationNonce;

    /// @notice Whether activation modules must be approved by the controller owner.
    bool public moduleApprovalRequired;

    mapping(bytes32 activationId => ActivationData activation) private _activations;
    mapping(address module => bool approved) public approvedModules;

    /// @notice Activation does not exist.
    error ActivationNotFound(bytes32 activationId);
    /// @notice Activation is currently disabled.
    error ActivationNotActive(bytes32 activationId);
    /// @notice Caller is not the activation owner.
    error NotActivationOwner(bytes32 activationId, address caller);
    /// @notice Module address is zero.
    error ZeroModule(bytes32 kind);
    /// @notice Module is not approved while approval enforcement is enabled.
    error UnapprovedModule(address module, bytes32 kind);
    /// @notice Registry address is zero.
    error ZeroRegistry();
    /// @notice Payment processor address is zero.
    error ZeroProcessor();
    /// @notice Activation owner address is zero.
    error ZeroActivationOwner();
    /// @notice Activator does not have registry-level authority to create an activation.
    error UnauthorizedActivationOwner(address caller, address registry);
    /// @notice Controller does not have registry minting permissions required by the activation.
    error ControllerMissingRegistryRoles(address registry, uint256 requiredRoles);
    /// @notice Duration cannot be zero.
    error ZeroDuration();
    /// @notice Runtime module data count does not match activation module count.
    error RuntimeDataLengthMismatch(bytes32 kind, uint256 expected, uint256 actual);
    /// @notice Label is not available in the configured ENSv2 registry.
    error LabelNotAvailable(string label, IPermissionedRegistry.Status status);
    /// @notice Label cannot be renewed because it is not currently registered or reserved.
    error LabelNotRenewable(string label, IPermissionedRegistry.Status status);

    /// @param initialOwner Owner of controller-level administration.
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc INamespaceController
    function activate(NamespaceTypes.ActivationConfig calldata config)
        external
        nonReentrant
        returns (bytes32 activationId)
    {
        if (address(config.registry) == address(0)) {
            revert ZeroRegistry();
        }
        if (config.paymentModule.module == address(0)) {
            revert ZeroModule(MODULE_KIND_PAYMENT);
        }
        if (config.processor.module == address(0)) {
            revert ZeroProcessor();
        }
        _checkRegistryAdminAuthority(msg.sender, config.registry);
        if (!config.registry.hasRootRoles(_ROLE_REGISTRAR | _ROLE_RENEW, address(this))) {
            revert ControllerMissingRegistryRoles(address(config.registry), _ROLE_REGISTRAR | _ROLE_RENEW);
        }

        uint256 nonce = ++activationNonce;
        activationId =
            keccak256(abi.encode(block.chainid, address(config.registry), config.parentNode, msg.sender, nonce));

        ActivationData storage activation = _activations[activationId];
        activation.owner = msg.sender;
        activation.registry = config.registry;
        activation.parentNode = config.parentNode;
        activation.resolver = config.resolver;
        activation.buyerRoleBitmap = config.buyerRoleBitmap;
        activation.active = true;
        activation.paymentModule = config.paymentModule.module;
        activation.processor = config.processor.module;

        _configureModules(activationId, MODULE_KIND_POLICY, config.policies, activation.policies);
        _configureModules(activationId, MODULE_KIND_PRICING, config.pricingModules, activation.pricingModules);
        _configureSingleModule(activationId, MODULE_KIND_PAYMENT, config.paymentModule);
        _configureSingleModule(activationId, MODULE_KIND_PROCESSOR, config.processor);
        _configureModules(activationId, MODULE_KIND_POST_HOOK, config.postHooks, activation.postHooks);

        emit ActivationCreated(activationId, msg.sender, address(config.registry), config.parentNode);
        emit ActivationStatusChanged(activationId, true);
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
        if (newOwner == address(0)) {
            revert ZeroActivationOwner();
        }

        ActivationData storage activation = _requireActivation(activationId);
        _checkActivationOwner(activationId, activation);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        _checkRegistryAdminAuthority(newOwner, activation.registry);

        address previousOwner = activation.owner;
        activation.owner = newOwner;
        emit ActivationOwnershipTransferred(activationId, previousOwner, newOwner);
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
        approvedModules[module] = approved;
        emit ModuleApprovalSet(module, approved);
    }

    /// @inheritdoc INamespaceController
    function mint(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable nonReentrant returns (uint256 tokenId) {
        if (duration == 0) {
            revert ZeroDuration();
        }

        ActivationData storage activation = _requireActivation(activationId);
        if (!activation.active) {
            revert ActivationNotActive(activationId);
        }

        _checkRuntimeDataLengths(activation, runtimeData);

        uint256 labelId = uint256(keccak256(bytes(label)));
        IPermissionedRegistry.State memory state = activation.registry.getState(labelId);
        if (state.status != IPermissionedRegistry.Status.AVAILABLE) {
            revert LabelNotAvailable(label, state.status);
        }

        NamespaceTypes.MintContext memory ctx = NamespaceTypes.MintContext({
            activationId: activationId,
            buyer: msg.sender,
            payer: msg.sender,
            registry: activation.registry,
            parentNode: activation.parentNode,
            label: label,
            labelHash: bytes32(labelId),
            duration: duration,
            expiry: uint64(block.timestamp) + duration,
            resolver: activation.resolver,
            buyerRoleBitmap: activation.buyerRoleBitmap
        });

        _checkMintPolicies(activation, ctx, runtimeData.policyData);
        NamespaceTypes.Price memory price = _quoteMint(activation, ctx, runtimeData.pricingData);

        IPaymentModule(activation.paymentModule).collectMint{value: msg.value}(ctx, price, runtimeData.paymentData);
        IProcessorModule(activation.processor).processMint(ctx, price, runtimeData.processorData);

        tokenId = activation.registry
            .register(
                label, msg.sender, IRegistry(address(0)), activation.resolver, activation.buyerRoleBitmap, ctx.expiry
            );

        _runPostMintHooks(activation, ctx, tokenId, runtimeData.postHookData);

        emit SubnameMinted(activationId, bytes32(labelId), label, msg.sender, tokenId, price.token, price.amount);
    }

    /// @inheritdoc INamespaceController
    function renew(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable nonReentrant returns (uint64 newExpiry) {
        if (duration == 0) {
            revert ZeroDuration();
        }

        ActivationData storage activation = _requireActivation(activationId);
        if (!activation.active) {
            revert ActivationNotActive(activationId);
        }

        _checkRuntimeDataLengths(activation, runtimeData);

        uint256 labelId = uint256(keccak256(bytes(label)));
        IPermissionedRegistry.State memory state = activation.registry.getState(labelId);
        if (state.status == IPermissionedRegistry.Status.AVAILABLE) {
            revert LabelNotRenewable(label, state.status);
        }

        newExpiry = state.expiry + duration;

        NamespaceTypes.RenewContext memory ctx = NamespaceTypes.RenewContext({
            activationId: activationId,
            payer: msg.sender,
            registry: activation.registry,
            parentNode: activation.parentNode,
            label: label,
            labelHash: bytes32(labelId),
            tokenId: state.tokenId,
            duration: duration,
            currentExpiry: state.expiry,
            newExpiry: newExpiry
        });

        _checkRenewPolicies(activation, ctx, runtimeData.policyData);
        NamespaceTypes.Price memory price = _quoteRenew(activation, ctx, runtimeData.pricingData);

        IPaymentModule(activation.paymentModule).collectRenew{value: msg.value}(ctx, price, runtimeData.paymentData);
        IProcessorModule(activation.processor).processRenew(ctx, price, runtimeData.processorData);

        activation.registry.renew(state.tokenId, newExpiry);

        _runPostRenewHooks(activation, ctx, runtimeData.postHookData);

        emit SubnameRenewed(activationId, bytes32(labelId), label, state.tokenId, newExpiry, price.token, price.amount);
    }

    /// @inheritdoc INamespaceController
    function getActivation(bytes32 activationId) external view returns (NamespaceTypes.Activation memory activation) {
        ActivationData storage stored = _requireActivationView(activationId);
        activation = NamespaceTypes.Activation({
            owner: stored.owner,
            registry: stored.registry,
            parentNode: stored.parentNode,
            resolver: stored.resolver,
            buyerRoleBitmap: stored.buyerRoleBitmap,
            active: stored.active,
            paymentModule: stored.paymentModule,
            processor: stored.processor
        });
    }

    /// @notice Return configured policy modules for an activation.
    function getPolicies(bytes32 activationId) external view returns (address[] memory policies) {
        policies = _requireActivationView(activationId).policies;
    }

    /// @notice Return configured pricing modules for an activation.
    function getPricingModules(bytes32 activationId) external view returns (address[] memory pricingModules) {
        pricingModules = _requireActivationView(activationId).pricingModules;
    }

    /// @notice Return configured post-mint hooks for an activation.
    function getPostHooks(bytes32 activationId) external view returns (address[] memory postHooks) {
        postHooks = _requireActivationView(activationId).postHooks;
    }

    function _configureModules(
        bytes32 activationId,
        bytes32 kind,
        NamespaceTypes.ModuleConfig[] calldata configs,
        address[] storage modules
    ) private {
        uint256 length = configs.length;
        for (uint256 i; i < length;) {
            NamespaceTypes.ModuleConfig calldata config = configs[i];
            _checkModule(config.module, kind);
            modules.push(config.module);
            IConfigurableModule(config.module).configure(activationId, config.configData);
            emit ModuleConfigured(activationId, config.module, kind);
            unchecked {
                ++i;
            }
        }
    }

    function _configureSingleModule(bytes32 activationId, bytes32 kind, NamespaceTypes.ModuleConfig calldata config)
        private
    {
        _checkModule(config.module, kind);
        IConfigurableModule(config.module).configure(activationId, config.configData);
        emit ModuleConfigured(activationId, config.module, kind);
    }

    function _checkModule(address module, bytes32 kind) private view {
        if (module == address(0)) {
            revert ZeroModule(kind);
        }
        if (moduleApprovalRequired && !approvedModules[module]) {
            revert UnapprovedModule(module, kind);
        }
    }

    function _checkMintPolicies(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        bytes[] calldata policyData
    ) private {
        uint256 length = activation.policies.length;
        for (uint256 i; i < length;) {
            IPolicyModule(activation.policies[i]).checkMint(ctx, policyData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _quoteMint(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        bytes[] calldata pricingData
    ) private view returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.pricingModules.length;
        for (uint256 i; i < length;) {
            price = IPricingModule(activation.pricingModules[i]).quoteMint(ctx, price, pricingData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _checkRenewPolicies(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata policyData
    ) private {
        uint256 length = activation.policies.length;
        for (uint256 i; i < length;) {
            IPolicyModule(activation.policies[i]).checkRenew(ctx, policyData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _quoteRenew(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata pricingData
    ) private view returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.pricingModules.length;
        for (uint256 i; i < length;) {
            price = IPricingModule(activation.pricingModules[i]).quoteRenew(ctx, price, pricingData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _runPostMintHooks(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        uint256 tokenId,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHooks.length;
        for (uint256 i; i < length;) {
            IPostHookModule(activation.postHooks[i]).afterMint(ctx, tokenId, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _runPostRenewHooks(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHooks.length;
        for (uint256 i; i < length;) {
            IPostHookModule(activation.postHooks[i]).afterRenew(ctx, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _checkRuntimeDataLengths(
        ActivationData storage activation,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) private view {
        if (runtimeData.policyData.length != activation.policies.length) {
            revert RuntimeDataLengthMismatch(
                MODULE_KIND_POLICY, activation.policies.length, runtimeData.policyData.length
            );
        }
        if (runtimeData.pricingData.length != activation.pricingModules.length) {
            revert RuntimeDataLengthMismatch(
                MODULE_KIND_PRICING, activation.pricingModules.length, runtimeData.pricingData.length
            );
        }
        if (runtimeData.postHookData.length != activation.postHooks.length) {
            revert RuntimeDataLengthMismatch(
                MODULE_KIND_POST_HOOK, activation.postHooks.length, runtimeData.postHookData.length
            );
        }
    }

    function _requireActivation(bytes32 activationId) private view returns (ActivationData storage activation) {
        activation = _activations[activationId];
        if (activation.owner == address(0)) {
            revert ActivationNotFound(activationId);
        }
    }

    function _requireActivationView(bytes32 activationId) private view returns (ActivationData storage activation) {
        activation = _activations[activationId];
        if (activation.owner == address(0)) {
            revert ActivationNotFound(activationId);
        }
    }

    function _checkActivationOwner(bytes32 activationId, ActivationData storage activation) private view {
        if (msg.sender != activation.owner) {
            revert NotActivationOwner(activationId, msg.sender);
        }
    }

    function _checkRegistryAdminAuthority(address account, IPermissionedRegistry registry) private view {
        if (!registry.hasRootRoles(_ROLE_REGISTRAR_ADMIN, account)) {
            revert UnauthorizedActivationOwner(account, address(registry));
        }
    }
}
