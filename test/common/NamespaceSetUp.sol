// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {LabelLengthPolicy} from "src/modules/policies/LabelLengthPolicy.sol";
import {SaleWindowPolicy} from "src/modules/policies/SaleWindowPolicy.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {NoopProcessor} from "src/modules/processors/NoopProcessor.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPermissionedRegistry} from "test/mocks/MockPermissionedRegistry.sol";
import {RecordingPostHook} from "test/mocks/RecordingPostHook.sol";

contract NamespaceSetUp is Test {
    uint256 internal constant ROLE_REGISTRAR = 1 << 0;
    uint256 internal constant ROLE_REGISTRAR_ADMIN = ROLE_REGISTRAR << 128;
    uint256 internal constant ROLE_RENEW = 1 << 16;
    uint256 internal constant ROLE_SET_RESOLVER = 1 << 24;
    uint256 internal constant ROLE_SET_RESOLVER_ADMIN = ROLE_SET_RESOLVER << 128;
    uint256 internal constant ROLE_CAN_TRANSFER_ADMIN = (1 << 28) << 128;
    uint256 internal constant BUYER_ROLES = ROLE_SET_RESOLVER | ROLE_SET_RESOLVER_ADMIN | ROLE_CAN_TRANSFER_ADMIN;

    struct Accounts {
        Vm.Wallet alice;
        Vm.Wallet buyer;
        Vm.Wallet treasury;
        Vm.Wallet owner;
    }

    Accounts internal accounts;
    NamespaceController internal controller;
    MockPermissionedRegistry internal registry;
    MockERC20 internal token;
    SaleWindowPolicy internal saleWindowPolicy;
    LabelLengthPolicy internal labelLengthPolicy;
    FixedPricePricing internal fixedPricePricing;
    ERC20PaymentModule internal erc20Payment;
    NoopProcessor internal noopProcessor;
    RecordingPostHook internal postHook;

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

        controller = new NamespaceController(accounts.owner.addr);
        registry = new MockPermissionedRegistry();
        token = new MockERC20("Mock USDC", "mUSDC");
        saleWindowPolicy = new SaleWindowPolicy(address(controller));
        labelLengthPolicy = new LabelLengthPolicy(address(controller));
        fixedPricePricing = new FixedPricePricing(address(controller));
        erc20Payment = new ERC20PaymentModule(address(controller));
        noopProcessor = new NoopProcessor(address(controller));
        postHook = new RecordingPostHook(address(controller));

        registry.grantRootRoles(ROLE_REGISTRAR_ADMIN, accounts.alice.addr);
        registry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));
        token.mint(accounts.buyer.addr, 1_000_000 ether);

        _approveDefaultModules();
    }

    function _defaultActivationConfig() internal view returns (NamespaceTypes.ActivationConfig memory config) {
        NamespaceTypes.ModuleConfig[] memory policies = new NamespaceTypes.ModuleConfig[](2);
        policies[0] = NamespaceTypes.ModuleConfig({
            module: address(saleWindowPolicy),
            configData: abi.encode(SaleWindowPolicy.Params({startTime: 0, endTime: 0}))
        });
        policies[1] = NamespaceTypes.ModuleConfig({
            module: address(labelLengthPolicy),
            configData: abi.encode(LabelLengthPolicy.Params({minLength: 3, maxLength: 12}))
        });

        NamespaceTypes.ModuleConfig[] memory pricingModules = new NamespaceTypes.ModuleConfig[](1);
        pricingModules[0] = NamespaceTypes.ModuleConfig({
            module: address(fixedPricePricing),
            configData: abi.encode(
                FixedPricePricing.Params({
                    token: address(token),
                    defaultMintAmount: 100 ether,
                    defaultRenewAmount: 50 ether,
                    lengthPrices: new FixedPricePricing.LengthPrice[](0)
                })
            )
        });

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});

        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            policies: policies,
            pricingModules: pricingModules,
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(erc20Payment),
                configData: abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
            }),
            processor: NamespaceTypes.ModuleConfig({module: address(noopProcessor), configData: ""}),
            postHooks: postHooks
        });
    }

    function _defaultRuntimeData() internal pure returns (NamespaceTypes.RuntimeData memory runtimeData) {
        runtimeData.policyData = new bytes[](2);
        runtimeData.pricingData = new bytes[](1);
        runtimeData.paymentData = "";
        runtimeData.processorData = "";
        runtimeData.postHookData = new bytes[](1);
        runtimeData.postHookData[0] = hex"1234";
    }

    function _activateDefault() internal returns (bytes32 activationId) {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }

    function _approveDefaultModules() internal {
        bytes32 policyKind = controller.MODULE_KIND_POLICY();
        bytes32 pricingKind = controller.MODULE_KIND_PRICING();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();
        bytes32 processorKind = controller.MODULE_KIND_PROCESSOR();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(policyKind, address(saleWindowPolicy), true);
        controller.setModuleApproval(policyKind, address(labelLengthPolicy), true);
        controller.setModuleApproval(pricingKind, address(fixedPricePricing), true);
        controller.setModuleApproval(paymentKind, address(erc20Payment), true);
        controller.setModuleApproval(processorKind, address(noopProcessor), true);
        controller.setModuleApproval(postHookKind, address(postHook), true);
        vm.stopPrank();
    }
}
