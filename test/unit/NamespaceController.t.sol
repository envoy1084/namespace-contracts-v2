// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {Vm} from "forge-std/Vm.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceControllerTest is NamespaceSetUp {
    bytes32 private constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    event ActivationOwnershipTransferred(
        bytes32 indexed activationId, address indexed previousOwner, address indexed newOwner
    );
    event ModuleApprovalRequiredSet(bool required);
    event ModuleApprovalSet(bytes32 indexed kind, address indexed module, bool approved);

    function test_activate_storesActivationAndConfiguresModules() public {
        bytes32 activationId = _activateDefault();

        NamespaceTypes.Activation memory activation = controller.getActivation(activationId);
        assertEq(activation.owner, accounts.alice.addr);
        assertEq(address(activation.registry), address(registry));
        assertEq(activation.parentNode, keccak256("alice.eth"));
        assertEq(activation.resolver, address(0xBEEF));
        assertEq(activation.buyerRoleBitmap, BUYER_ROLES);
        assertTrue(activation.active);
        assertEq(activation.paymentModule, address(erc20Payment));

        address[] memory rules = controller.getRules(activationId);
        assertEq(rules.length, 3);
        assertEq(rules[0], address(saleWindowRule));
        assertEq(rules[1], address(labelLengthRule));
        assertEq(rules[2], address(fixedPriceRule));

        (uint64 startTime, uint64 endTime) = saleWindowRule.params(activationId);
        assertEq(startTime, 0);
        assertEq(endTime, 0);

        (address priceToken, uint128 mintAmount, uint128 renewAmount) = fixedPriceRule.params(activationId);
        assertEq(priceToken, address(token));
        assertEq(mintAmount, 100 ether);
        assertEq(renewAmount, 50 ether);
    }

    function test_upgradeController_allowsOwner() public {
        NamespaceController newImplementation = new NamespaceController();

        vm.prank(accounts.owner.addr);
        controller.upgradeToAndCall(address(newImplementation), "");

        assertEq(
            address(uint160(uint256(vm.load(address(controller), _ERC1967_IMPLEMENTATION_SLOT)))),
            address(newImplementation)
        );
    }

    function test_upgradeController_revertsForNonOwner() public {
        NamespaceController newImplementation = new NamespaceController();

        vm.expectRevert();
        vm.prank(accounts.buyer.addr);
        controller.upgradeToAndCall(address(newImplementation), "");
    }

    function test_upgradeModule_allowsOwner() public {
        SaleWindowRule newImplementation = new SaleWindowRule();

        vm.prank(accounts.owner.addr);
        saleWindowRule.upgradeToAndCall(address(newImplementation), "");

        assertEq(
            address(uint160(uint256(vm.load(address(saleWindowRule), _ERC1967_IMPLEMENTATION_SLOT)))),
            address(newImplementation)
        );
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

    function test_updateModuleConfig_revertsForNonActivationOwner() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.expectRevert(
            abi.encodeWithSelector(NamespaceController.NotActivationOwner.selector, activationId, accounts.buyer.addr)
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
                NamespaceController.UnauthorizedActivationOwner.selector, accounts.alice.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId, ruleKind, 0, abi.encode(SaleWindowRule.Params({startTime: 1, endTime: 2}))
        );
    }

    function test_activate_revertsWhenCallerLacksRegistryAdmin() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();

        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.UnauthorizedActivationOwner.selector, accounts.buyer.addr, address(registry)
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.activate(config);
    }

    function test_setActivationStatus_revertsWhenOwnerLostRegistryAdmin() public {
        bytes32 activationId = _activateDefault();
        registry.revokeRootRoles(ROLE_REGISTRAR_ADMIN, accounts.alice.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.UnauthorizedActivationOwner.selector, accounts.alice.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.setActivationStatus(activationId, false);
    }

    function test_transferActivationOwnership_requiresNewOwnerRegistryAdmin() public {
        bytes32 activationId = _activateDefault();

        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.UnauthorizedActivationOwner.selector, accounts.buyer.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.transferActivationOwnership(activationId, accounts.buyer.addr);
    }

    function test_transferActivationOwnership_updatesOwner() public {
        bytes32 activationId = _activateDefault();
        registry.grantRootRoles(ROLE_REGISTRAR_ADMIN, accounts.owner.addr);

        vm.expectEmit(true, true, true, true, address(controller));
        emit ActivationOwnershipTransferred(activationId, accounts.alice.addr, accounts.owner.addr);

        vm.prank(accounts.alice.addr);
        controller.transferActivationOwnership(activationId, accounts.owner.addr);

        NamespaceTypes.Activation memory activation = controller.getActivation(activationId);
        assertEq(activation.owner, accounts.owner.addr);

        vm.prank(accounts.owner.addr);
        controller.setActivationStatus(activationId, false);

        activation = controller.getActivation(activationId);
        assertFalse(activation.active);
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
                NamespaceController.UnapprovedModule.selector, address(unapprovedRule), controller.MODULE_KIND_RULE()
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
            abi.encodeWithSelector(NamespaceController.UnapprovedModule.selector, address(unapprovedRule), ruleKind)
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_succeedsWhenAllModulesAreApproved() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.Activation memory activation = controller.getActivation(activationId);
        assertEq(activation.owner, accounts.alice.addr);
    }

    function test_mint_runsModulesCollectsPaymentAndRegistersLabel() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        uint256 tokenId = controller.mint(activationId, "pay", 365 days, runtimeData);
        vm.stopPrank();

        uint256 labelId = uint256(keccak256(bytes("pay")));
        assertEq(token.balanceOf(accounts.treasury.addr), 100 ether);
        IPermissionedRegistry.State memory state = registry.getState(labelId);
        assertEq(tokenId, state.tokenId);
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
        assertEq(registry.getResolver("pay"), address(0xBEEF));
        assertEq(registry.roles(tokenId, accounts.buyer.addr), BUYER_ROLES);

        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(state.latestOwner, accounts.buyer.addr);

        assertEq(postHook.lastActivationId(), activationId);
        assertEq(postHook.lastBuyer(), accounts.buyer.addr);
        assertEq(postHook.lastLabelHash(), bytes32(labelId));
        assertEq(postHook.lastTokenId(), tokenId);
        assertEq(postHook.lastRuntimeData(), hex"1234");
    }

    function test_mint_revertsWhenRuntimeRuleDataLengthDoesNotMatch() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.ruleData = new bytes[](1);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.RuntimeDataLengthMismatch.selector, controller.MODULE_KIND_RULE(), 3, 1
            )
        );
        controller.mint(activationId, "pay", 365 days, runtimeData);
        vm.stopPrank();
    }

    function test_renew_runsModulesCollectsPaymentAndExtendsExpiry() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 150 ether);
        uint256 tokenId = controller.mint(activationId, "pay", 365 days, runtimeData);

        IPermissionedRegistry.State memory beforeRenew = registry.getState(tokenId);
        uint64 newExpiry = controller.renew(activationId, "pay", 30 days, runtimeData);
        vm.stopPrank();

        IPermissionedRegistry.State memory afterRenew = registry.getState(tokenId);
        assertEq(newExpiry, beforeRenew.expiry + 30 days);
        assertEq(afterRenew.expiry, newExpiry);
        assertEq(token.balanceOf(accounts.treasury.addr), 150 ether);
    }

    function test_renew_revertsWhenLabelIsAvailable() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 50 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.LabelNotRenewable.selector, "pay", IPermissionedRegistry.Status.AVAILABLE
            )
        );
        controller.renew(activationId, "pay", 30 days, runtimeData);
        vm.stopPrank();
    }

    function test_mint_respectsReservationRule() public {
        ReservationRule reservationRule = ReservationRule(_deployModule(address(new ReservationRule())));
        Vm.Wallet memory reservedBuyer = vm.createWallet("reservedBuyer");
        token.mint(reservedBuyer.addr, 1_000 ether);
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(reservationRule), true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        uint64 expiry = uint64(block.timestamp + 1 days);
        bytes32 labelHash = keccak256(bytes("vip"));
        ReservationRule.Claim memory claim = ReservationRule.Claim({
            labelHash: labelHash,
            account: reservedBuyer.addr,
            startTime: 0,
            endTime: expiry,
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
        bytes32 reservationRoot = reservationRule.leaf(claim);
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](4);
        rules[0] = config.rules[0];
        rules[1] = config.rules[1];
        rules[2] = NamespaceTypes.RuleConfig({
            module: address(reservationRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(ReservationRule.Params({root: reservationRoot}))
        });
        rules[3] = config.rules[2];
        config.rules = rules;

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.ruleData = new bytes[](4);
        runtimeData.ruleData[2] = abi.encode(claim);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationRule.ReservedForDifferentAccount.selector,
                activationId,
                labelHash,
                reservedBuyer.addr,
                accounts.buyer.addr
            )
        );
        controller.mint(activationId, "vip", 365 days, runtimeData);
        vm.stopPrank();

        vm.startPrank(reservedBuyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        uint256 tokenId = controller.mint(activationId, "vip", 365 days, runtimeData);
        vm.stopPrank();

        assertEq(registry.ownerOf(tokenId), reservedBuyer.addr);
    }
}
