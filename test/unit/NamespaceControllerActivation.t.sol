// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";
import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {PermissionedRegistry} from "@ensv2/registry/PermissionedRegistry.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {IUniversalResolverV2} from "src/interfaces/IUniversalResolverV2.sol";
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
        assertEq(address(activation.parentRegistry), address(ethRegistry));
        assertEq(activation.parentNode, _aliceNode());
        IPermissionedRegistry.State memory parentState = ethRegistry.getState(uint256(keccak256(bytes("alice"))));
        assertEq(activation.namespaceResource, parentState.resource);
        assertEq(activation.namespaceKey, activationId);
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
        controller.activate(_aliceName(), config);
    }

    function test_activate_revertsForInvalidDurationBounds() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.minDuration = 30 days;
        config.maxDuration = 7 days;

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.InvalidDurationBounds.selector, uint64(30 days), uint64(7 days))
        );
        vm.prank(accounts.alice.addr);
        controller.activate(_aliceName(), config);

        config.minDuration = 0;
        config.maxDuration = 0;

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.InvalidDurationBounds.selector, uint64(0), uint64(0))
        );
        vm.prank(accounts.alice.addr);
        controller.activate(_aliceName(), config);
    }

    function test_activate_succeedsWhenAllModulesAreApproved() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(_aliceName(), config);

        NamespaceTypes.Activation memory activation = controller.getActivation(activationId);
        assertEq(activation.owner, accounts.alice.addr);
    }

    function test_activate_revertsWhenNamespaceAlreadyActivated() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.NamespaceAlreadyActivated.selector, activationId, activationId)
        );
        vm.prank(accounts.alice.addr);
        controller.activate(_aliceName(), config);
    }

    function test_setUniversalResolver_revertsForZeroResolver() public {
        vm.expectRevert(abi.encodeWithSelector(INamespaceController.ZeroUniversalResolver.selector));
        vm.prank(accounts.owner.addr);
        controller.setUniversalResolver(IUniversalResolverV2(address(0)));
    }

    function test_activate_revertsWhenUniversalResolverIsNotConfigured() public {
        NamespaceController freshController = _deployController(accounts.owner.addr);
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.UniversalResolverNotConfigured.selector));
        vm.prank(accounts.alice.addr);
        freshController.activate(_aliceName(), config);
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
        controller.activate(_aliceName(), config);
    }

    function test_activate_revertsForRootNamespaceName() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.InvalidNamespaceName.selector, hex"00"));
        vm.prank(accounts.alice.addr);
        controller.activate(hex"00", config);
    }

    function test_activate_revertsWhenNamespaceRegistryDoesNotExist() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory missingName = NameCoder.encode("missing.eth");

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.NamespaceRegistryNotFound.selector, missingName));
        vm.prank(accounts.alice.addr);
        controller.activate(missingName, config);
    }

    function test_activate_revertsWhenNamespaceIsReserved() public {
        PermissionedRegistry reservedRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        ethRegistry.register(
            "reserved", address(0), IRegistry(address(reservedRegistry)), address(0), 0, type(uint64).max
        );
        reservedRegistry.setParent(ethRegistry, "reserved");

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory reservedName = NameCoder.encode("reserved.eth");

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.NamespaceNotRegistered.selector,
                reservedName,
                IPermissionedRegistry.Status.RESERVED
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(reservedName, config);
    }

    function test_activate_revertsWhenCanonicalRegistryCannotBeProven() public {
        PermissionedRegistry wrongRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        ethRegistry.register(
            "wrong", accounts.owner.addr, IRegistry(address(wrongRegistry)), address(0), 0, type(uint64).max
        );
        wrongRegistry.setParent(ethRegistry, "other");

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory wrongName = NameCoder.encode("wrong.eth");

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.NamespaceRegistryNotFound.selector, wrongName));
        vm.prank(accounts.alice.addr);
        controller.activate(wrongName, config);
    }

    function test_activate_revertsWhenUniversalResolverOmitsParentRegistry() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory aliceName = _aliceName();
        IRegistry[] memory registries = new IRegistry[](1);
        registries[0] = registry;
        universalResolver.setCanonicalRegistryOverride(registry);
        universalResolver.setRegistriesOverride(registries);

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.NamespaceParentRegistryNotFound.selector, aliceName)
        );
        vm.prank(accounts.alice.addr);
        controller.activate(aliceName, config);
    }

    function test_activate_revertsWhenUniversalResolverRegistryListDisagreesWithCanonicalRegistry() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory aliceName = _aliceName();
        IRegistry[] memory registries = new IRegistry[](2);
        registries[0] = ethRegistry;
        registries[1] = ethRegistry;
        universalResolver.setCanonicalRegistryOverride(registry);
        universalResolver.setRegistriesOverride(registries);

        vm.expectRevert(abi.encodeWithSelector(INamespaceController.NamespaceRegistryNotFound.selector, aliceName));
        vm.prank(accounts.alice.addr);
        controller.activate(aliceName, config);
    }

    function test_activate_revertsWhenParentRegistryNoLongerPointsToResolvedRegistry() public {
        PermissionedRegistry originalRegistry = _registerMutableNamespace("drift");
        PermissionedRegistry replacementRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        replacementRegistry.setParent(ethRegistry, "drift");
        bytes memory driftName = NameCoder.encode("drift.eth");
        IRegistry[] memory registries = new IRegistry[](2);
        registries[0] = originalRegistry;
        registries[1] = ethRegistry;
        universalResolver.setCanonicalRegistryOverride(originalRegistry);
        universalResolver.setRegistriesOverride(registries);

        vm.prank(accounts.owner.addr);
        ethRegistry.setSubregistry(uint256(keccak256(bytes("drift"))), replacementRegistry);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        vm.expectRevert(abi.encodeWithSelector(INamespaceController.NamespaceRegistryNotFound.selector, driftName));
        vm.prank(accounts.alice.addr);
        controller.activate(driftName, config);
    }

    function test_mint_revertsWhenParentSubregistryChangesAfterActivation() public {
        PermissionedRegistry originalRegistry = _registerMutableNamespace("mutable");
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory mutableName = NameCoder.encode("mutable.eth");

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(mutableName, config);

        PermissionedRegistry replacementRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        replacementRegistry.setParent(ethRegistry, "mutable");
        vm.prank(accounts.owner.addr);
        ethRegistry.setSubregistry(uint256(keccak256(bytes("mutable"))), IRegistry(address(replacementRegistry)));

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.NamespaceRegistryChanged.selector,
                activationId,
                address(originalRegistry),
                address(replacementRegistry)
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, _defaultRuntimeData());
    }

    function test_mint_revertsWhenParentNamespaceIsUnavailableAfterActivation() public {
        _registerMutableNamespace("gone");
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory goneName = NameCoder.encode("gone.eth");

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(goneName, config);

        vm.prank(accounts.owner.addr);
        ethRegistry.unregister(uint256(keccak256(bytes("gone"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.NamespaceActivationUnavailable.selector,
                activationId,
                IPermissionedRegistry.Status.AVAILABLE
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, _defaultRuntimeData());
    }

    function test_reRegisteringNamespaceAllowsNewActivationAndStalesOldActivation() public {
        _registerMutableNamespace("cycle");
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        bytes memory cycleName = NameCoder.encode("cycle.eth");

        vm.prank(accounts.alice.addr);
        bytes32 oldActivationId = controller.activate(cycleName, config);
        uint256 oldResource = controller.getActivation(oldActivationId).namespaceResource;

        vm.prank(accounts.owner.addr);
        ethRegistry.unregister(uint256(keccak256(bytes("cycle"))));

        PermissionedRegistry replacementRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        ethRegistry.register(
            "cycle",
            accounts.owner.addr,
            IRegistry(address(replacementRegistry)),
            address(0),
            ROLE_SET_SUBREGISTRY | ROLE_UNREGISTER,
            type(uint64).max
        );
        replacementRegistry.setParent(ethRegistry, "cycle");
        replacementRegistry.grantRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, accounts.alice.addr);
        replacementRegistry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));

        vm.prank(accounts.alice.addr);
        bytes32 newActivationId = controller.activate(cycleName, config);
        uint256 newResource = ethRegistry.getState(uint256(keccak256(bytes("cycle")))).resource;
        assertNotEq(newActivationId, oldActivationId);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.NamespaceActivationStale.selector, oldActivationId, oldResource, newResource
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(oldActivationId, "pay", 365 days, _defaultRuntimeData());
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

    function _registerMutableNamespace(string memory label) private returns (PermissionedRegistry namespaceRegistry) {
        namespaceRegistry = new PermissionedRegistry(
            IHCAFactoryBasic(address(0)),
            registryMetadata,
            address(this),
            ROLE_SET_PARENT | ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN
        );
        ethRegistry.register(
            label,
            accounts.owner.addr,
            IRegistry(address(namespaceRegistry)),
            address(0),
            ROLE_SET_SUBREGISTRY | ROLE_UNREGISTER,
            type(uint64).max
        );
        namespaceRegistry.setParent(ethRegistry, label);
        namespaceRegistry.grantRootRoles(ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN, accounts.alice.addr);
        namespaceRegistry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(controller));
    }
}
