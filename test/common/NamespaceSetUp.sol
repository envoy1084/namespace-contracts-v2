// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {LibClone} from "solady/utils/LibClone.sol";

import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";
import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {RegistryRolesLib} from "@ensv2/registry/libraries/RegistryRolesLib.sol";
import {PermissionedRegistry} from "@ensv2/registry/PermissionedRegistry.sol";
import {SimpleRegistryMetadata} from "@ensv2/registry/SimpleRegistryMetadata.sol";
import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LabelLengthRule} from "src/modules/rules/LabelLengthRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockUniversalResolverV2} from "test/mocks/MockUniversalResolverV2.sol";
import {RecordingPostHook} from "test/mocks/RecordingPostHook.sol";

abstract contract NamespaceSetUp is Test {
    uint256 internal constant ROLE_REGISTRAR = RegistryRolesLib.ROLE_REGISTRAR;
    uint256 internal constant ROLE_REGISTRAR_ADMIN = RegistryRolesLib.ROLE_REGISTRAR_ADMIN;
    uint256 internal constant ROLE_RENEW = RegistryRolesLib.ROLE_RENEW;
    uint256 internal constant ROLE_RENEW_ADMIN = RegistryRolesLib.ROLE_RENEW_ADMIN;
    uint256 internal constant ROLE_UNREGISTER = RegistryRolesLib.ROLE_UNREGISTER;
    uint256 internal constant ROLE_SET_PARENT = RegistryRolesLib.ROLE_SET_PARENT;
    uint256 internal constant ROLE_SET_SUBREGISTRY = RegistryRolesLib.ROLE_SET_SUBREGISTRY;
    uint256 internal constant ROLE_SET_RESOLVER = RegistryRolesLib.ROLE_SET_RESOLVER;
    uint256 internal constant ROLE_SET_RESOLVER_ADMIN = RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN;
    uint256 internal constant ROLE_CAN_TRANSFER_ADMIN = RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN;
    uint256 internal constant BUYER_ROLES = ROLE_SET_RESOLVER | ROLE_SET_RESOLVER_ADMIN | ROLE_CAN_TRANSFER_ADMIN;

    struct Accounts {
        Vm.Wallet alice;
        Vm.Wallet buyer;
        Vm.Wallet treasury;
        Vm.Wallet owner;
    }

    Accounts internal accounts;
    NamespaceController internal controller;
    SimpleRegistryMetadata internal registryMetadata;
    PermissionedRegistry internal rootRegistry;
    PermissionedRegistry internal ethRegistry;
    PermissionedRegistry internal registry;
    MockUniversalResolverV2 internal universalResolver;
    MockERC20 internal token;
    ERC20PaymentModule internal erc20Payment;
    RecordingPostHook internal postHook;
    SaleWindowRule internal saleWindowRule;
    LabelLengthRule internal labelLengthRule;
    FixedPriceRule internal fixedPriceRule;

    function setUp() public virtual {
        accounts = Accounts({
            alice: vm.createWallet("alice"),
            buyer: vm.createWallet("buyer"),
            treasury: vm.createWallet("treasury"),
            owner: vm.createWallet("owner")
        });

        vm.deal(accounts.alice.addr, 100 ether);
        vm.deal(accounts.buyer.addr, 100 ether);
        vm.deal(accounts.owner.addr, 100 ether);

        controller = _deployController(accounts.owner.addr);
        registryMetadata = new SimpleRegistryMetadata(IHCAFactoryBasic(address(0)));
        rootRegistry =
            new PermissionedRegistry(IHCAFactoryBasic(address(0)), registryMetadata, address(this), ROLE_REGISTRAR);
        ethRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)), registryMetadata, address(this), ROLE_REGISTRAR | ROLE_SET_PARENT
        );
        registry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_REGISTER_RESERVED_ADMIN
        );
        rootRegistry.register(
            "eth", accounts.owner.addr, IRegistry(address(ethRegistry)), address(0), 0, type(uint64).max
        );
        ethRegistry.setParent(rootRegistry, "eth");
        ethRegistry.register(
            "alice", accounts.owner.addr, IRegistry(address(registry)), address(0), 0, type(uint64).max
        );
        registry.setParent(ethRegistry, "alice");
        universalResolver = new MockUniversalResolverV2(rootRegistry);
        vm.prank(accounts.owner.addr);
        controller.setUniversalResolver(universalResolver);
        token = new MockERC20("Mock USDC", "mUSDC");
        erc20Payment = ERC20PaymentModule(_deployModule(address(new ERC20PaymentModule())));
        postHook = RecordingPostHook(_deployModule(address(new RecordingPostHook())));
        saleWindowRule = SaleWindowRule(_deployModule(address(new SaleWindowRule())));
        labelLengthRule = LabelLengthRule(_deployModule(address(new LabelLengthRule())));
        fixedPriceRule = FixedPriceRule(_deployModule(address(new FixedPriceRule())));

        registry.grantRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, accounts.alice.addr);
        registry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));
        token.mint(accounts.buyer.addr, 1_000_000 ether);

        _approveDefaultModules();
    }

    function _defaultActivationConfig() internal view returns (NamespaceTypes.ActivationConfig memory config) {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](3);
        rules[0] = NamespaceTypes.RuleConfig({
            module: address(saleWindowRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });
        rules[1] = NamespaceTypes.RuleConfig({
            module: address(labelLengthRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(LabelLengthRule.Params({minLength: 3, maxLength: 12}))
        });
        rules[2] = NamespaceTypes.RuleConfig({
            module: address(fixedPriceRule),
            phase: NamespaceTypes.RulePhase.BASE_PRICE,
            configData: abi.encode(
                FixedPriceRule.Params({
                    token: address(token),
                    defaultMintAmount: 100 ether,
                    defaultRenewAmount: 50 ether,
                    lengthPrices: new FixedPriceRule.LengthPrice[](0)
                })
            )
        });

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});

        config = NamespaceTypes.ActivationConfig({
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            minDuration: 1,
            maxDuration: 365 days,
            rules: rules,
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(erc20Payment),
                configData: abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
            }),
            postHooks: postHooks
        });
    }

    function _defaultRuntimeData() internal pure returns (NamespaceTypes.RuntimeData memory runtimeData) {
        runtimeData.ruleData = new bytes[](3);
        runtimeData.paymentData = "";
        runtimeData.postHookData = new bytes[](1);
        runtimeData.postHookData[0] = hex"1234";
    }

    function _activateDefault() internal returns (bytes32 activationId) {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        vm.prank(accounts.alice.addr);
        activationId = controller.activate(_aliceName(), config);
    }

    function _activateNamespace(string memory label, NamespaceTypes.ActivationConfig memory config)
        internal
        returns (bytes32 activationId)
    {
        _registerNamespace(label);
        vm.prank(accounts.alice.addr);
        activationId = controller.activate(_namespaceName(label), config);
    }

    function _registerNamespace(string memory label) internal returns (PermissionedRegistry namespaceRegistry) {
        namespaceRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_REGISTER_RESERVED_ADMIN
        );
        ethRegistry.register(
            label, accounts.owner.addr, IRegistry(address(namespaceRegistry)), address(0), 0, type(uint64).max
        );
        namespaceRegistry.setParent(ethRegistry, label);
        namespaceRegistry.grantRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, accounts.alice.addr);
        namespaceRegistry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));
    }

    function _aliceNode() internal pure returns (bytes32) {
        return NameCoder.namehash(NameCoder.ETH_NODE, keccak256(bytes("alice")));
    }

    function _aliceName() internal pure returns (bytes memory) {
        return NameCoder.encode("alice.eth");
    }

    function _namespaceName(string memory label) internal pure returns (bytes memory) {
        return NameCoder.encode(string.concat(label, ".eth"));
    }

    function _deployController(address owner_) internal returns (NamespaceController deployed) {
        address implementation = address(new NamespaceController());
        deployed = NamespaceController(payable(LibClone.deployERC1967(implementation)));
        deployed.initialize(owner_);
    }

    function _deployModule(address implementation) internal returns (address deployed) {
        deployed = LibClone.deployERC1967(implementation);
        (bool success, bytes memory returndata) = deployed.call(
            abi.encodeWithSignature("initialize(address,address)", address(controller), accounts.owner.addr)
        );
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }

    function _approveDefaultModules() internal {
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(saleWindowRule), true);
        controller.setModuleApproval(ruleKind, address(labelLengthRule), true);
        controller.setModuleApproval(ruleKind, address(fixedPriceRule), true);
        controller.setModuleApproval(paymentKind, address(erc20Payment), true);
        controller.setModuleApproval(postHookKind, address(postHook), true);
        vm.stopPrank();
    }
}
