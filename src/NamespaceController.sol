// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

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
contract NamespaceController is INamespaceController, Ownable, Initializable, ReentrancyGuard, UUPSUpgradeable {
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
        bytes policies;
        bytes pricingModules;
        bytes postHooks;
    }

    /// @notice Total number of activations created by this controller.
    uint256 public activationNonce;

    /// @notice Whether activation modules must be approved by the controller owner.
    bool public moduleApprovalRequired;

    mapping(bytes32 activationId => ActivationData activation) private _activations;
    mapping(bytes32 kind => mapping(address module => bool approved)) public approvedModules;

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
    /// @notice Module index does not exist for the requested activation and kind.
    error ModuleIndexOutOfBounds(bytes32 activationId, bytes32 kind, uint256 index, uint256 length);
    /// @notice Label is not available in the configured ENSv2 registry.
    error LabelNotAvailable(string label, IPermissionedRegistry.Status status);
    /// @notice Label cannot be renewed because it is not currently registered or reserved.
    error LabelNotRenewable(string label, IPermissionedRegistry.Status status);

    constructor() {
        _disableInitializers();
    }

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
        if (address(config.registry) == address(0)) {
            revert ZeroRegistry();
        }
        if (config.paymentModule.module == address(0)) {
            revert ZeroModule(MODULE_KIND_PAYMENT);
        }
        if (config.processor.module == address(0)) {
            revert ZeroProcessor();
        }
        uint256 nonce = ++activationNonce;
        activationId =
            keccak256(abi.encode(block.chainid, address(config.registry), config.parentNode, msg.sender, nonce));

        bytes memory policies = _packModules(MODULE_KIND_POLICY, config.policies);
        bytes memory pricingModules = _packModules(MODULE_KIND_PRICING, config.pricingModules);
        bytes memory postHooks = _packModules(MODULE_KIND_POST_HOOK, config.postHooks);
        _checkModule(config.paymentModule.module, MODULE_KIND_PAYMENT);
        _checkModule(config.processor.module, MODULE_KIND_PROCESSOR);
        _checkRegistryAdminAuthority(msg.sender, config.registry);
        if (!config.registry.hasRootRoles(_ROLE_REGISTRAR | _ROLE_RENEW, address(this))) {
            revert ControllerMissingRegistryRoles(address(config.registry), _ROLE_REGISTRAR | _ROLE_RENEW);
        }

        _storeActivation(activationId, config, policies, pricingModules, postHooks);

        emit ActivationCreated(activationId, msg.sender, address(config.registry), config.parentNode);
        emit ActivationStatusChanged(activationId, true);

        _configureModules(activationId, MODULE_KIND_POLICY, config.policies);
        _configureModules(activationId, MODULE_KIND_PRICING, config.pricingModules);
        if (config.pricingModules.length != 0) {
            _configureSingleModule(activationId, MODULE_KIND_PAYMENT, config.paymentModule);
            _configureSingleModule(activationId, MODULE_KIND_PROCESSOR, config.processor);
        }
        _configureModules(activationId, MODULE_KIND_POST_HOOK, config.postHooks);
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
    function updateModuleConfig(bytes32 activationId, bytes32 kind, uint256 index, bytes calldata configData) external {
        _checkKnownModuleKind(kind);

        ActivationData storage activation = _requireActivation(activationId);
        _checkActivationOwner(activationId, activation);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);

        address module = _moduleAt(activation, activationId, kind, index);
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
        _setModuleApproval(MODULE_KIND_POLICY, module, approved);
        _setModuleApproval(MODULE_KIND_PRICING, module, approved);
        _setModuleApproval(MODULE_KIND_PAYMENT, module, approved);
        _setModuleApproval(MODULE_KIND_PROCESSOR, module, approved);
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

        NamespaceTypes.MintContext memory ctx = _mintContext(activation, activationId, label, labelId, duration);

        _checkMintPolicies(activation, ctx, runtimeData.policyData);
        NamespaceTypes.Price memory price = _quoteMint(activation, ctx, runtimeData.pricingData);

        if (price.amount != 0 || msg.value != 0) {
            IPaymentModule(activation.paymentModule).collectMint{value: msg.value}(ctx, price, runtimeData.paymentData);
            IProcessorModule(activation.processor).processMint(ctx, price, runtimeData.processorData);
        }

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

        if (price.amount != 0 || msg.value != 0) {
            IPaymentModule(activation.paymentModule).collectRenew{value: msg.value}(ctx, price, runtimeData.paymentData);
            IProcessorModule(activation.processor).processRenew(ctx, price, runtimeData.processorData);
        }

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
        bytes memory packedModules = _requireActivationView(activationId).policies;
        policies = _unpackModules(packedModules);
    }

    /// @notice Return configured pricing modules for an activation.
    function getPricingModules(bytes32 activationId) external view returns (address[] memory pricingModules) {
        bytes memory packedModules = _requireActivationView(activationId).pricingModules;
        pricingModules = _unpackModules(packedModules);
    }

    /// @notice Return configured post-mint hooks for an activation.
    function getPostHooks(bytes32 activationId) external view returns (address[] memory postHooks) {
        bytes memory packedModules = _requireActivationView(activationId).postHooks;
        postHooks = _unpackModules(packedModules);
    }

    function _storeActivation(
        bytes32 activationId,
        NamespaceTypes.ActivationConfig calldata config,
        bytes memory policies,
        bytes memory pricingModules,
        bytes memory postHooks
    ) private {
        ActivationData storage activation = _activations[activationId];
        activation.owner = msg.sender;
        activation.registry = config.registry;
        activation.parentNode = config.parentNode;
        activation.resolver = config.resolver;
        activation.buyerRoleBitmap = config.buyerRoleBitmap;
        activation.active = true;
        activation.paymentModule = config.paymentModule.module;
        activation.processor = config.processor.module;
        activation.policies = policies;
        activation.pricingModules = pricingModules;
        activation.postHooks = postHooks;
    }

    function _packModules(bytes32 kind, NamespaceTypes.ModuleConfig[] calldata configs)
        private
        view
        returns (bytes memory modules)
    {
        uint256 length = configs.length;
        modules = new bytes(length * 20);
        for (uint256 i; i < length;) {
            NamespaceTypes.ModuleConfig calldata config = configs[i];
            _checkModule(config.module, kind);
            _packModule(modules, i, config.module);
            unchecked {
                ++i;
            }
        }
    }

    function _configureModules(bytes32 activationId, bytes32 kind, NamespaceTypes.ModuleConfig[] calldata configs)
        private
    {
        uint256 length = configs.length;
        for (uint256 i; i < length;) {
            NamespaceTypes.ModuleConfig calldata config = configs[i];
            emit ModuleConfigured(activationId, config.module, kind);
            IConfigurableModule(config.module).configure(activationId, config.configData);
            unchecked {
                ++i;
            }
        }
    }

    function _configureSingleModule(bytes32 activationId, bytes32 kind, NamespaceTypes.ModuleConfig calldata config)
        private
    {
        _checkModule(config.module, kind);
        emit ModuleConfigured(activationId, config.module, kind);
        IConfigurableModule(config.module).configure(activationId, config.configData);
    }

    function _checkModule(address module, bytes32 kind) private view {
        if (module == address(0)) {
            revert ZeroModule(kind);
        }
        if (moduleApprovalRequired && !approvedModules[kind][module]) {
            revert UnapprovedModule(module, kind);
        }
    }

    function _setModuleApproval(bytes32 kind, address module, bool approved) private {
        approvedModules[kind][module] = approved;
        emit ModuleApprovalSet(kind, module, approved);
    }

    function _moduleAt(ActivationData storage activation, bytes32 activationId, bytes32 kind, uint256 index)
        private
        view
        returns (address module)
    {
        if (kind == MODULE_KIND_PAYMENT) {
            if (index != 0) {
                revert ModuleIndexOutOfBounds(activationId, kind, index, 1);
            }
            return activation.paymentModule;
        }
        if (kind == MODULE_KIND_PROCESSOR) {
            if (index != 0) {
                revert ModuleIndexOutOfBounds(activationId, kind, index, 1);
            }
            return activation.processor;
        }

        bytes storage modules;
        if (kind == MODULE_KIND_POLICY) {
            modules = activation.policies;
        } else if (kind == MODULE_KIND_PRICING) {
            modules = activation.pricingModules;
        } else {
            modules = activation.postHooks;
        }

        uint256 length = modules.length / 20;
        if (index >= length) {
            revert ModuleIndexOutOfBounds(activationId, kind, index, length);
        }
        bytes memory packedModules = modules;
        module = _moduleAt(packedModules, index);
    }

    function _checkKnownModuleKind(bytes32 kind) private pure {
        if (
            kind != MODULE_KIND_POLICY && kind != MODULE_KIND_PRICING && kind != MODULE_KIND_PAYMENT
                && kind != MODULE_KIND_PROCESSOR && kind != MODULE_KIND_POST_HOOK
        ) {
            revert ZeroModule(kind);
        }
    }

    function _checkMintPolicies(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        bytes[] calldata policyData
    ) private {
        bytes memory policies = activation.policies;
        uint256 length = policies.length / 20;
        for (uint256 i; i < length;) {
            IPolicyModule(_moduleAt(policies, i)).checkMint(ctx, policyData[i]);
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
        bytes memory pricingModules = activation.pricingModules;
        uint256 length = pricingModules.length / 20;
        for (uint256 i; i < length;) {
            price = IPricingModule(_moduleAt(pricingModules, i)).quoteMint(ctx, price, pricingData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _mintContext(
        ActivationData storage activation,
        bytes32 activationId,
        string calldata label,
        uint256 labelId,
        uint64 duration
    ) private view returns (NamespaceTypes.MintContext memory ctx) {
        ctx = NamespaceTypes.MintContext({
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
    }

    function _checkRenewPolicies(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata policyData
    ) private {
        bytes memory policies = activation.policies;
        uint256 length = policies.length / 20;
        for (uint256 i; i < length;) {
            IPolicyModule(_moduleAt(policies, i)).checkRenew(ctx, policyData[i]);
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
        bytes memory pricingModules = activation.pricingModules;
        uint256 length = pricingModules.length / 20;
        for (uint256 i; i < length;) {
            price = IPricingModule(_moduleAt(pricingModules, i)).quoteRenew(ctx, price, pricingData[i]);
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
        bytes memory postHooks = activation.postHooks;
        uint256 length = postHooks.length / 20;
        for (uint256 i; i < length;) {
            IPostHookModule(_moduleAt(postHooks, i)).afterMint(ctx, tokenId, postHookData[i]);
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
        bytes memory postHooks = activation.postHooks;
        uint256 length = postHooks.length / 20;
        for (uint256 i; i < length;) {
            IPostHookModule(_moduleAt(postHooks, i)).afterRenew(ctx, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _checkRuntimeDataLengths(
        ActivationData storage activation,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) private view {
        uint256 policyLength = activation.policies.length / 20;
        if (runtimeData.policyData.length != policyLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_POLICY, policyLength, runtimeData.policyData.length);
        }
        uint256 pricingLength = activation.pricingModules.length / 20;
        if (runtimeData.pricingData.length != pricingLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_PRICING, pricingLength, runtimeData.pricingData.length);
        }
        uint256 postHookLength = activation.postHooks.length / 20;
        if (runtimeData.postHookData.length != postHookLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_POST_HOOK, postHookLength, runtimeData.postHookData.length);
        }
    }

    function _packModule(bytes memory modules, uint256 index, address module) private pure {
        uint256 offset = 32 + index * 20;
        assembly ("memory-safe") {
            let word := mload(add(modules, offset))
            mstore(add(modules, offset), or(shl(96, module), and(word, 0xffffffffffffffffffffffff)))
        }
    }

    function _moduleAt(bytes memory modules, uint256 index) private pure returns (address module) {
        uint256 offset = 32 + index * 20;
        assembly ("memory-safe") {
            module := shr(96, mload(add(modules, offset)))
        }
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
