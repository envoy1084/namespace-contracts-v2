// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";
import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {PermissionedRegistry} from "@ensv2/registry/PermissionedRegistry.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceControllerActivationTest is NamespaceSetUp {
    bytes32 private constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    event ActivationOwnershipTransferred(
        bytes32 indexed activationId, address indexed previousOwner, address indexed newOwner
    );

    function test_activate_storesActivationAndConfiguresModules() public {
        bytes32 activationId = _activateDefault();

        NamespaceTypes.Activation memory activation = controller.getActivation(activationId);
        assertEq(activation.owner, accounts.alice.addr);
        assertEq(address(activation.registry), address(registry));
        assertEq(activation.parentNode, _aliceNode());
        assertEq(activation.resolver, address(0xBEEF));
        assertEq(activation.buyerRoleBitmap, BUYER_ROLES);
        assertEq(activation.minDuration, 1);
        assertEq(activation.maxDuration, 365 days);
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

    function test_activate_revertsWhenCallerLacksRegistryAdmin() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnauthorizedActivationOwner.selector, accounts.buyer.addr, address(registry)
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.activate(config);
    }

    function test_activate_revertsForInvalidDurationBounds() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.minDuration = 30 days;
        config.maxDuration = 7 days;

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.InvalidDurationBounds.selector, uint64(30 days), uint64(7 days))
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);

        config.minDuration = 0;
        config.maxDuration = 0;

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.InvalidDurationBounds.selector, uint64(0), uint64(0))
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

    function test_activate_revertsWhenCallerLacksRenewAdmin() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        registry.revokeRootRoles(ROLE_RENEW_ADMIN, accounts.alice.addr);
        assertFalse(registry.hasRootRoles(ROLE_RENEW_ADMIN, accounts.alice.addr));

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnauthorizedActivationOwner.selector, accounts.alice.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsWhenParentNodeDoesNotMatchRegistry() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes32 victimNode = keccak256("victim.eth");
        config.parentNode = victimNode;

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RegistryParentNodeMismatch.selector, address(registry), _aliceNode(), victimNode
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsWhenRegistryChainDoesNotReachConfiguredRoot() public {
        PermissionedRegistry fakeRoot =
            new PermissionedRegistry(IHCAFactoryBasic(address(0)), registryMetadata, address(this), ROLE_REGISTRAR);
        PermissionedRegistry fakeEth = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)), registryMetadata, address(this), ROLE_REGISTRAR | ROLE_SET_PARENT
        );
        PermissionedRegistry fakeRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        fakeRoot.register("eth", accounts.owner.addr, IRegistry(address(fakeEth)), address(0), 0, type(uint64).max);
        fakeEth.setParent(fakeRoot, "eth");
        fakeEth.register(
            "alice", accounts.owner.addr, IRegistry(address(fakeRegistry)), address(0), 0, type(uint64).max
        );
        fakeRegistry.setParent(fakeEth, "alice");
        fakeRegistry.grantRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, accounts.alice.addr);
        fakeRegistry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.registry = IPermissionedRegistry(address(fakeRegistry));
        config.parentNode = _aliceNode();

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.RegistryParentNotConfigured.selector, address(fakeRoot))
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_setActivationStatus_revertsWhenOwnerLostRegistryAdmin() public {
        bytes32 activationId = _activateDefault();
        registry.revokeRootRoles(ROLE_REGISTRAR_ADMIN, accounts.alice.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnauthorizedActivationOwner.selector, accounts.alice.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.setActivationStatus(activationId, false);
    }

    function test_transferActivationOwnership_requiresNewOwnerRegistryAdmin() public {
        bytes32 activationId = _activateDefault();

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnauthorizedActivationOwner.selector, accounts.buyer.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.transferActivationOwnership(activationId, accounts.buyer.addr);
    }

    function test_transferActivationOwnership_revertsForZeroNewOwner() public {
        bytes32 activationId = _activateDefault();

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ZeroActivationOwner.selector));
        vm.prank(accounts.alice.addr);
        controller.transferActivationOwnership(activationId, address(0));
    }

    function test_transferActivationOwnership_updatesOwner() public {
        bytes32 activationId = _activateDefault();
        registry.grantRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, accounts.owner.addr);

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
}
