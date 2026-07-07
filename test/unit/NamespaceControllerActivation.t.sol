// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

    function test_activate_succeedsWhenAllModulesAreApproved() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.Activation memory activation = controller.getActivation(activationId);
        assertEq(activation.owner, accounts.alice.addr);
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
