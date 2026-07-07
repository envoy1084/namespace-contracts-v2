// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {RecordingPostHook} from "test/mocks/RecordingPostHook.sol";

contract NamespaceControllerModulesTest is NamespaceSetUp {
    function test_setModuleApproval_overloadApprovesAllKinds() public {
        SaleWindowRule module = SaleWindowRule(_deployModule(address(new SaleWindowRule())));

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(address(module), true);

        assertTrue(controller.approvedModules(controller.MODULE_KIND_RULE(), address(module)));
        assertTrue(controller.approvedModules(controller.MODULE_KIND_PAYMENT(), address(module)));
        assertTrue(controller.approvedModules(controller.MODULE_KIND_POST_HOOK(), address(module)));
    }

    function test_setModuleApproval_revertsForZeroModule() public {
        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ZeroModule.selector, bytes32(0)));
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(address(0), true);
    }

    function test_setModuleApproval_revertsForZeroKindModule() public {
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ZeroModule.selector, ruleKind));
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(0), true);
    }

    function test_setModuleApproval_revertsForUnknownKind() public {
        bytes32 unknownKind = keccak256("UNKNOWN");

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ZeroModule.selector, unknownKind));
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(unknownKind, address(saleWindowRule), true);
    }

    function test_updateModuleConfig_allowsActivationOwner() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId,
            ruleKind,
            0,
            abi.encode(
                SaleWindowRule.Params({startTime: uint64(block.timestamp + 1), endTime: uint64(block.timestamp + 2)})
            )
        );

        (uint64 startTime, uint64 endTime) = saleWindowRule.params(activationId);
        assertEq(startTime, uint64(block.timestamp + 1));
        assertEq(endTime, uint64(block.timestamp + 2));
    }

    function test_updateModuleConfig_revertsWhenRuleModuleRevoked() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(saleWindowRule), false);

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.UnapprovedModule.selector, address(saleWindowRule), ruleKind)
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId,
            ruleKind,
            0,
            abi.encode(
                SaleWindowRule.Params({startTime: uint64(block.timestamp + 1), endTime: uint64(block.timestamp + 2)})
            )
        );
    }

    function test_mint_revertsWhenRuleModuleRevoked() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(fixedPriceRule), false);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.UnapprovedModule.selector, address(fixedPriceRule), ruleKind)
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, runtimeData);
    }

    function test_mint_revertsWhenPaymentModuleRevoked() public {
        bytes32 activationId = _activateDefault();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(paymentKind, address(erc20Payment), false);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.UnapprovedModule.selector, address(erc20Payment), paymentKind)
        );
        controller.mint(activationId, "pay", 365 days, runtimeData);
        vm.stopPrank();
    }

    function test_mint_revertsWhenPostHookModuleRevoked() public {
        bytes32 activationId = _activateDefault();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(postHookKind, address(postHook), false);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.UnapprovedModule.selector, address(postHook), postHookKind)
        );
        controller.mint(activationId, "pay", 365 days, runtimeData);
        vm.stopPrank();
    }

    function test_updateModuleConfig_allowsSingleRuleFastPath() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](1);
        rules[0] = NamespaceTypes.RuleConfig({
            module: address(saleWindowRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });
        config.rules = rules;

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId,
            ruleKind,
            0,
            abi.encode(
                SaleWindowRule.Params({startTime: uint64(block.timestamp + 1), endTime: uint64(block.timestamp + 2)})
            )
        );
    }

    function test_updateModuleConfig_allowsSinglePostHookFastPath() public {
        bytes32 activationId = _activateDefault();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(activationId, postHookKind, 0, "");
    }

    function test_updateModuleConfig_allowsPaymentModule() public {
        bytes32 activationId = _activateDefault();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();

        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId,
            paymentKind,
            0,
            abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.owner.addr}))
        );

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        controller.mint(activationId, "pay", 365 days, _defaultRuntimeData());
        vm.stopPrank();

        assertEq(token.balanceOf(accounts.owner.addr), 100 ether);
    }

    function test_updateModuleConfig_revertsForPaymentIndexOutOfBounds() public {
        bytes32 activationId = _activateDefault();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.ModuleIndexOutOfBounds.selector, activationId, paymentKind, 1, 1
            )
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId,
            paymentKind,
            1,
            abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.owner.addr}))
        );
    }

    function test_updateModuleConfig_revertsForRuleIndexOutOfBounds() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.ModuleIndexOutOfBounds.selector, activationId, ruleKind, 3, 3)
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId, ruleKind, 3, abi.encode(SaleWindowRule.Params({startTime: 1, endTime: 2}))
        );
    }

    function test_updateModuleConfig_revertsForPostHookIndexOutOfBounds() public {
        bytes32 activationId = _activateDefault();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.ModuleIndexOutOfBounds.selector, activationId, postHookKind, 1, 1
            )
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(activationId, postHookKind, 1, "");
    }

    function test_updateModuleConfig_allowsSecondPostHookInPackedList() public {
        RecordingPostHook secondPostHook = RecordingPostHook(_deployModule(address(new RecordingPostHook())));
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(postHookKind, address(secondPostHook), true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](2);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});
        postHooks[1] = NamespaceTypes.ModuleConfig({module: address(secondPostHook), configData: ""});
        config.postHooks = postHooks;

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(activationId, postHookKind, 1, "");
    }

    function test_updateModuleConfig_revertsForNonActivationOwner() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.NotActivationOwner.selector, activationId, accounts.buyer.addr)
        );
        vm.prank(accounts.buyer.addr);
        controller.updateModuleConfig(
            activationId, ruleKind, 0, abi.encode(SaleWindowRule.Params({startTime: 1, endTime: 2}))
        );
    }

    function test_updateModuleConfig_revertsWhenOwnerLostRegistryAdmin() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        registry.revokeRootRoles(ROLE_REGISTRAR_ADMIN, accounts.alice.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnauthorizedActivationOwner.selector, accounts.alice.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId, ruleKind, 0, abi.encode(SaleWindowRule.Params({startTime: 1, endTime: 2}))
        );
    }

    function test_activate_revertsWhenModuleApprovalRequiredAndModuleIsUnapproved() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        SaleWindowRule unapprovedRule = SaleWindowRule(_deployModule(address(new SaleWindowRule())));
        config.rules[0] = NamespaceTypes.RuleConfig({
            module: address(unapprovedRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnapprovedModule.selector, address(unapprovedRule), controller.MODULE_KIND_RULE()
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsWhenModuleIsApprovedForDifferentKind() public {
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        SaleWindowRule unapprovedRule = SaleWindowRule(_deployModule(address(new SaleWindowRule())));

        vm.prank(accounts.owner.addr);
        controller.setModuleApprovalRequired(true);

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(paymentKind, address(unapprovedRule), true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.rules[0] = NamespaceTypes.RuleConfig({
            module: address(unapprovedRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.UnapprovedModule.selector, address(unapprovedRule), ruleKind)
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsForTooManyRules() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.rules = new NamespaceTypes.RuleConfig[](256);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.ModuleListTooLong.selector, controller.MODULE_KIND_RULE(), uint256(256)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsForTooManyPostHooks() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.postHooks = new NamespaceTypes.ModuleConfig[](256);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.ModuleListTooLong.selector, controller.MODULE_KIND_POST_HOOK(), uint256(256)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsForZeroPostHookModule() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.postHooks[0] = NamespaceTypes.ModuleConfig({module: address(0), configData: ""});

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.ZeroModule.selector, controller.MODULE_KIND_POST_HOOK())
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsForOutOfOrderRulePhases() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.rules[0] = NamespaceTypes.RuleConfig({
            module: address(fixedPriceRule),
            phase: NamespaceTypes.RulePhase.BASE_PRICE,
            configData: config.rules[2].configData
        });
        config.rules[1] = NamespaceTypes.RuleConfig({
            module: address(saleWindowRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: config.rules[0].configData
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RulePhaseOrderInvalid.selector,
                1,
                NamespaceTypes.RulePhase.BASE_PRICE,
                NamespaceTypes.RulePhase.GUARD
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsForZeroRegistry() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.registry = IPermissionedRegistry(address(0));

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ZeroRegistry.selector));
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsWhenControllerMissingRegistryRoles() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        registry.revokeRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.ControllerMissingRegistryRoles.selector,
                address(registry),
                ROLE_REGISTRAR | ROLE_RENEW
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_getActivation_revertsWhenActivationMissing() public {
        bytes32 activationId = keccak256("missing");

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ActivationNotFound.selector, activationId));
        controller.getActivation(activationId);
    }

    function test_getRulesAndPostHooks_returnsEmptyLists() public {
        NamespaceTypes.ActivationConfig memory config = NamespaceTypes.ActivationConfig({
            registry: registry,
            parentNode: _aliceNode(),
            resolver: address(0),
            buyerRoleBitmap: 0,
            minDuration: 1,
            maxDuration: 365 days,
            rules: new NamespaceTypes.RuleConfig[](0),
            paymentModule: NamespaceTypes.ModuleConfig({module: address(0), configData: ""}),
            postHooks: new NamespaceTypes.ModuleConfig[](0)
        });

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        assertEq(controller.getRules(activationId).length, 0);
        assertEq(controller.getPostHooks(activationId).length, 0);
    }

    function test_getRulesAndPostHooks_returnsSingleModules() public {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](1);
        rules[0] = NamespaceTypes.RuleConfig({
            module: address(saleWindowRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});

        NamespaceTypes.ActivationConfig memory config = NamespaceTypes.ActivationConfig({
            registry: registry,
            parentNode: _aliceNode(),
            resolver: address(0xBEEF),
            buyerRoleBitmap: 0,
            minDuration: 1,
            maxDuration: 365 days,
            rules: rules,
            paymentModule: NamespaceTypes.ModuleConfig({module: address(0), configData: ""}),
            postHooks: postHooks
        });

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        address[] memory storedRules = controller.getRules(activationId);
        assertEq(storedRules.length, 1);
        assertEq(storedRules[0], address(saleWindowRule));

        address[] memory storedPostHooks = controller.getPostHooks(activationId);
        assertEq(storedPostHooks.length, 1);
        assertEq(storedPostHooks[0], address(postHook));
    }

    function test_getPostHooks_returnsMultipleModulesAndRenewRunsAllHooks() public {
        RecordingPostHook secondPostHook = RecordingPostHook(_deployModule(address(new RecordingPostHook())));
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(postHookKind, address(secondPostHook), true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](2);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});
        postHooks[1] = NamespaceTypes.ModuleConfig({module: address(secondPostHook), configData: ""});
        config.postHooks = postHooks;

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        address[] memory storedPostHooks = controller.getPostHooks(activationId);
        assertEq(storedPostHooks.length, 2);
        assertEq(storedPostHooks[0], address(postHook));
        assertEq(storedPostHooks[1], address(secondPostHook));

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.postHookData = new bytes[](2);
        runtimeData.postHookData[0] = hex"aaaa";
        runtimeData.postHookData[1] = hex"bbbb";

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 150 ether);
        uint256 tokenId = controller.mint(activationId, "pay", 365 days, runtimeData);
        uint64 newExpiry = controller.renew(activationId, "pay", 30 days, runtimeData);
        vm.stopPrank();

        assertEq(postHook.lastTokenId(), tokenId);
        assertEq(postHook.lastNewExpiry(), newExpiry);
        assertEq(postHook.lastRuntimeData(), hex"aaaa");
        assertEq(secondPostHook.lastTokenId(), tokenId);
        assertEq(secondPostHook.lastNewExpiry(), newExpiry);
        assertEq(secondPostHook.lastRuntimeData(), hex"bbbb");
    }

    function test_mint_revertsWhenPostHookRuntimeDataLengthDoesNotMatch() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.postHookData = new bytes[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RuntimeDataLengthMismatch.selector, controller.MODULE_KIND_POST_HOOK(), 1, 0
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, runtimeData);
    }
}
