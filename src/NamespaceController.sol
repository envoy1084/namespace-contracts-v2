// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {IConfigurableModule} from "src/interfaces/IConfigurableModule.sol";
import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {IRuleModule} from "src/interfaces/IRuleModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

/// @title NamespaceController
/// @notice Activation-based controller for minting ENSv2 subnames through official registries.
/// @dev The controller stores sale activations, delegates rule/payment/hook execution to modules,
///      and writes ownership to an ENSv2 `IPermissionedRegistry`.
contract NamespaceController is INamespaceController, Ownable, Initializable, ReentrancyGuard, UUPSUpgradeable {
    /// @notice Module kind emitted for rule configuration.
    bytes32 public constant MODULE_KIND_RULE = keccak256("RULE");
    /// @notice Module kind emitted for payment configuration.
    bytes32 public constant MODULE_KIND_PAYMENT = keccak256("PAYMENT");
    /// @notice Module kind emitted for post-hook configuration.
    bytes32 public constant MODULE_KIND_POST_HOOK = keccak256("POST_HOOK");

    uint256 private constant _BPS_DENOMINATOR = 10_000;

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
        bool tokenSet;
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
    /// @notice Activation has too many modules for one module kind.
    error ModuleListTooLong(bytes32 kind, uint256 length);
    /// @notice Rule phases must be sorted in ascending order.
    error RulePhaseOrderInvalid(uint256 index, NamespaceTypes.RulePhase previous, NamespaceTypes.RulePhase current);
    /// @notice Rule blocked the mint or renewal through a generic effect.
    error RuleBlocked(bytes32 activationId, address rule, uint256 index);
    /// @notice Rule requires flags that earlier rules did not add.
    error RequiredRuleFlagsMissing(bytes32 activationId, address rule, uint256 index, uint256 required, uint256 actual);
    /// @notice Rule attempted to mix payment tokens in the default engine.
    error RulePaymentTokenMismatch(address expected, address actual);
    /// @notice Rule returned an invalid basis-point value.
    error InvalidRuleBps(address rule, uint16 bps);
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
        NamespaceTypes.MintContext memory ctx = _mintContext(activation, activationId, label, labelId, duration);

        NamespaceTypes.Price memory price = _evaluateMintRules(activation, ctx, runtimeData.ruleData);

        tokenId = activation.registry
            .register(
                label, msg.sender, IRegistry(address(0)), activation.resolver, activation.buyerRoleBitmap, ctx.expiry
            );

        _collectMint(activation, ctx, price, runtimeData.paymentData);

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

        NamespaceTypes.Price memory price = _evaluateRenewRules(activation, ctx, runtimeData.ruleData);

        activation.registry.renew(state.tokenId, newExpiry);

        _collectRenew(activation, ctx, price, runtimeData.paymentData);

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
            paymentModule: stored.paymentModule
        });
    }

    /// @notice Return configured rule modules for an activation.
    function getRules(bytes32 activationId) external view returns (address[] memory rules) {
        ActivationData storage activation = _requireActivationView(activationId);
        uint256 length = activation.ruleCount;
        rules = new address[](length);
        if (length == 0) {
            return rules;
        }
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
        ActivationData storage activation = _requireActivationView(activationId);
        bytes memory packedModules = _readModuleList(activation.postHooks, activation.postHookCount);
        postHooks = _unpackModules(packedModules);
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
        ActivationData storage activation = _activations[activationId];
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
        if (address(config.registry) == address(0)) {
            revert ZeroRegistry();
        }
        if (config.paymentModule.module != address(0)) {
            _checkModule(config.paymentModule.module, MODULE_KIND_PAYMENT);
        }
        _checkRegistryAdminAuthority(msg.sender, config.registry);
        if (!config.registry.hasRootRoles(_ROLE_REGISTRAR | _ROLE_RENEW, address(this))) {
            revert ControllerMissingRegistryRoles(address(config.registry), _ROLE_REGISTRAR | _ROLE_RENEW);
        }
    }

    function _collectMint(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes calldata paymentData
    ) private {
        if (price.amount != 0 || msg.value != 0) {
            if (activation.paymentModule == address(0)) {
                revert ZeroModule(MODULE_KIND_PAYMENT);
            }
            IPaymentModule(activation.paymentModule).collectMint{value: msg.value}(ctx, price, paymentData);
        }
    }

    function _collectRenew(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes calldata paymentData
    ) private {
        if (price.amount != 0 || msg.value != 0) {
            if (activation.paymentModule == address(0)) {
                revert ZeroModule(MODULE_KIND_PAYMENT);
            }
            IPaymentModule(activation.paymentModule).collectRenew{value: msg.value}(ctx, price, paymentData);
        }
    }

    function _storeModuleList(bytes32 kind, NamespaceTypes.ModuleConfig[] calldata configs)
        private
        returns (address moduleData, uint8 count)
    {
        uint256 length = configs.length;
        if (length > type(uint8).max) {
            revert ModuleListTooLong(kind, length);
        }
        // casting to `uint8` is safe because `length` is bounded above.
        // forge-lint: disable-next-line(unsafe-typecast)
        count = uint8(length);
        if (length == 0) {
            return (address(0), count);
        }
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
        private
        returns (address ruleData, uint8 count, uint8 firstRulePhase)
    {
        uint256 length = configs.length;
        if (length > type(uint8).max) {
            revert ModuleListTooLong(MODULE_KIND_RULE, length);
        }
        // casting to `uint8` is safe because `length` is bounded above.
        // forge-lint: disable-next-line(unsafe-typecast)
        count = uint8(length);
        if (length == 0) {
            return (address(0), count, firstRulePhase);
        }

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

    function _configureModules(bytes32 activationId, NamespaceTypes.ModuleConfig[] calldata configs) private {
        uint256 length = configs.length;
        for (uint256 i; i < length;) {
            NamespaceTypes.ModuleConfig calldata config = configs[i];
            IConfigurableModule(config.module).configure(activationId, config.configData);
            unchecked {
                ++i;
            }
        }
    }

    function _configureRules(bytes32 activationId, NamespaceTypes.RuleConfig[] calldata configs) private {
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
        private
    {
        _checkModule(config.module, kind);
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
        if (kind == MODULE_KIND_RULE) {
            if (index >= activation.ruleCount) {
                revert ModuleIndexOutOfBounds(activationId, kind, index, activation.ruleCount);
            }
            if (activation.ruleCount == 1) {
                return activation.rules;
            }
            bytes memory packedRules = SSTORE2.read(activation.rules);
            return _ruleAt(packedRules, index).module;
        }
        if (kind == MODULE_KIND_PAYMENT) {
            uint256 paymentLength = activation.paymentModule == address(0) ? 0 : 1;
            if (index >= paymentLength) {
                revert ModuleIndexOutOfBounds(activationId, kind, index, paymentLength);
            }
            return activation.paymentModule;
        }

        address moduleData;
        uint8 moduleCount;
        moduleData = activation.postHooks;
        moduleCount = activation.postHookCount;

        if (index >= moduleCount) {
            revert ModuleIndexOutOfBounds(activationId, kind, index, moduleCount);
        }
        if (moduleCount == 1) {
            return moduleData;
        }
        bytes memory packedModules = SSTORE2.read(moduleData);
        module = _moduleAt(packedModules, index);
    }

    function _checkKnownModuleKind(bytes32 kind) private pure {
        if (kind != MODULE_KIND_RULE && kind != MODULE_KIND_PAYMENT && kind != MODULE_KIND_POST_HOOK) {
            revert ZeroModule(kind);
        }
    }

    function _evaluateMintRules(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        bytes[] calldata ruleData
    ) private returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.ruleCount;
        EvaluationState memory state = EvaluationState({amount: 0, flags: 0, token: address(0), tokenSet: false});
        if (length == 0) {
            return NamespaceTypes.Price({token: address(0), amount: 0});
        }
        if (length == 1) {
            _applyRuleOutput(
                ctx.activationId,
                activation.rules,
                0,
                IRuleModule(activation.rules).evaluateMint(ctx, ruleData[0]),
                state
            );
            return NamespaceTypes.Price({token: state.token, amount: state.amount});
        }
        bytes memory rules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            address rule = _ruleAt(rules, i).module;
            _applyRuleOutput(ctx.activationId, rule, i, IRuleModule(rule).evaluateMint(ctx, ruleData[i]), state);
            unchecked {
                ++i;
            }
        }
        price = NamespaceTypes.Price({token: state.token, amount: state.amount});
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

    function _evaluateRenewRules(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata ruleData
    ) private returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.ruleCount;
        EvaluationState memory state = EvaluationState({amount: 0, flags: 0, token: address(0), tokenSet: false});
        if (length == 0) {
            return NamespaceTypes.Price({token: address(0), amount: 0});
        }
        if (length == 1) {
            _applyRuleOutput(
                ctx.activationId,
                activation.rules,
                0,
                IRuleModule(activation.rules).evaluateRenew(ctx, ruleData[0]),
                state
            );
            return NamespaceTypes.Price({token: state.token, amount: state.amount});
        }
        bytes memory rules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            address rule = _ruleAt(rules, i).module;
            _applyRuleOutput(ctx.activationId, rule, i, IRuleModule(rule).evaluateRenew(ctx, ruleData[i]), state);
            unchecked {
                ++i;
            }
        }
        price = NamespaceTypes.Price({token: state.token, amount: state.amount});
    }

    // slither-disable-start incorrect-equality
    // slither-disable-start cyclomatic-complexity
    // solhint-disable-next-line function-max-lines
    function _applyRuleOutput(
        bytes32 activationId,
        address rule,
        uint256 index,
        NamespaceTypes.RuleOutput memory output,
        EvaluationState memory state
    ) private pure {
        if (output.requireFlags != 0 && (state.flags & output.requireFlags) != output.requireFlags) {
            revert RequiredRuleFlagsMissing(activationId, rule, index, output.requireFlags, state.flags);
        }
        if (output.decision == NamespaceTypes.Decision.BLOCK) {
            revert RuleBlocked(activationId, rule, index);
        }
        if (output.decision == NamespaceTypes.Decision.SKIP) {
            return;
        }

        state.flags |= output.addFlags;

        NamespaceTypes.PriceOp op = output.priceOp;
        if (op == NamespaceTypes.PriceOp.NONE) {
            return;
        }

        if (
            op == NamespaceTypes.PriceOp.SET_BASE || op == NamespaceTypes.PriceOp.ADD
                || op == NamespaceTypes.PriceOp.SUBTRACT || op == NamespaceTypes.PriceOp.MIN
                || op == NamespaceTypes.PriceOp.MAX || op == NamespaceTypes.PriceOp.OVERRIDE
        ) {
            _applyToken(output.token, state);
        }

        if (op == NamespaceTypes.PriceOp.SET_BASE || op == NamespaceTypes.PriceOp.OVERRIDE) {
            state.amount = output.amount;
        } else if (op == NamespaceTypes.PriceOp.ADD) {
            state.amount += output.amount;
        } else if (op == NamespaceTypes.PriceOp.SUBTRACT) {
            state.amount = output.amount > state.amount ? 0 : state.amount - output.amount;
        } else if (op == NamespaceTypes.PriceOp.DISCOUNT_BPS) {
            _checkBps(rule, output.bps);
            state.amount = (state.amount * (_BPS_DENOMINATOR - output.bps)) / _BPS_DENOMINATOR;
        } else if (op == NamespaceTypes.PriceOp.MARKUP_BPS) {
            _checkBps(rule, output.bps);
            state.amount = (state.amount * (_BPS_DENOMINATOR + output.bps)) / _BPS_DENOMINATOR;
        } else if (op == NamespaceTypes.PriceOp.MIN) {
            if (state.amount < output.amount) {
                state.amount = output.amount;
            }
        } else if (op == NamespaceTypes.PriceOp.MAX && state.amount > output.amount) {
            state.amount = output.amount;
        }
    }
    // slither-disable-end cyclomatic-complexity
    // slither-disable-end incorrect-equality

    function _applyToken(address token, EvaluationState memory state) private pure {
        if (!state.tokenSet) {
            state.token = token;
            state.tokenSet = true;
            return;
        }
        if (state.token != token) {
            revert RulePaymentTokenMismatch(state.token, token);
        }
    }

    function _checkBps(address rule, uint16 bps) private pure {
        if (bps > _BPS_DENOMINATOR) {
            revert InvalidRuleBps(rule, bps);
        }
    }

    function _runPostMintHooks(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        uint256 tokenId,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHookCount;
        if (length == 1) {
            IPostHookModule(activation.postHooks).afterMint(ctx, tokenId, postHookData[0]);
            return;
        }
        bytes memory postHooks = _readModuleList(activation.postHooks, length);
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
        uint256 length = activation.postHookCount;
        if (length == 1) {
            IPostHookModule(activation.postHooks).afterRenew(ctx, postHookData[0]);
            return;
        }
        bytes memory postHooks = _readModuleList(activation.postHooks, length);
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
        uint256 ruleLength = activation.ruleCount;
        if (runtimeData.ruleData.length != ruleLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_RULE, ruleLength, runtimeData.ruleData.length);
        }
        uint256 postHookLength = activation.postHookCount;
        if (runtimeData.postHookData.length != postHookLength) {
            revert RuntimeDataLengthMismatch(MODULE_KIND_POST_HOOK, postHookLength, runtimeData.postHookData.length);
        }
    }

    function _readModuleList(address moduleData, uint256 length) private view returns (bytes memory modules) {
        if (length == 0) {
            return new bytes(0);
        }
        if (length == 1) {
            modules = new bytes(20);
            _packModule(modules, 0, moduleData);
            return modules;
        }
        modules = SSTORE2.read(moduleData);
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

    function _moduleAt(bytes memory modules, uint256 index) private pure returns (address module) {
        uint256 offset = 32 + index * 20;
        assembly ("memory-safe") {
            module := shr(96, mload(add(modules, offset)))
        }
    }

    function _ruleAt(bytes memory rules, uint256 index) private pure returns (RuleRef memory rule) {
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
