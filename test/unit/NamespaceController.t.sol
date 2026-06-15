// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {Vm} from "forge-std/Vm.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {ReservationPolicy} from "src/modules/policies/ReservationPolicy.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceControllerTest is NamespaceSetUp {
    event ActivationOwnershipTransferred(
        bytes32 indexed activationId, address indexed previousOwner, address indexed newOwner
    );
    event ModuleApprovalRequiredSet(bool required);
    event ModuleApprovalSet(address indexed module, bool approved);

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
        assertEq(activation.processor, address(noopProcessor));

        address[] memory policies = controller.getPolicies(activationId);
        assertEq(policies.length, 2);
        assertEq(policies[0], address(saleWindowPolicy));
        assertEq(policies[1], address(labelLengthPolicy));

        address[] memory pricing = controller.getPricingModules(activationId);
        assertEq(pricing.length, 1);
        assertEq(pricing[0], address(fixedPricePricing));

        (uint64 startTime, uint64 endTime) = saleWindowPolicy.params(activationId);
        assertEq(startTime, 0);
        assertEq(endTime, 0);

        (address priceToken, uint128 mintAmount, uint128 renewAmount) = fixedPricePricing.params(activationId);
        assertEq(priceToken, address(token));
        assertEq(mintAmount, 100 ether);
        assertEq(renewAmount, 50 ether);
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
        vm.prank(accounts.owner.addr);
        controller.setModuleApprovalRequired(true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();

        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.UnapprovedModule.selector,
                address(saleWindowPolicy),
                controller.MODULE_KIND_POLICY()
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_succeedsWhenAllModulesAreApproved() public {
        _approveDefaultModules();

        vm.expectEmit(false, false, false, true, address(controller));
        emit ModuleApprovalRequiredSet(true);
        vm.prank(accounts.owner.addr);
        controller.setModuleApprovalRequired(true);

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
        assertEq(tokenId, labelId);
        assertEq(token.balanceOf(accounts.treasury.addr), 100 ether);
        assertEq(registry.ownerOf(labelId), accounts.buyer.addr);
        assertEq(registry.resolverOf(labelId), address(0xBEEF));
        assertEq(registry.rolesOf(labelId), BUYER_ROLES);

        IPermissionedRegistry.State memory state = registry.getState(labelId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(state.latestOwner, accounts.buyer.addr);

        assertEq(postHook.lastActivationId(), activationId);
        assertEq(postHook.lastBuyer(), accounts.buyer.addr);
        assertEq(postHook.lastLabelHash(), bytes32(labelId));
        assertEq(postHook.lastTokenId(), tokenId);
        assertEq(postHook.lastRuntimeData(), hex"1234");
    }

    function test_mint_revertsWhenRuntimePolicyDataLengthDoesNotMatch() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.policyData = new bytes[](1);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                NamespaceController.RuntimeDataLengthMismatch.selector, controller.MODULE_KIND_POLICY(), 2, 1
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

    function test_mint_respectsReservationPolicy() public {
        ReservationPolicy reservationPolicy = new ReservationPolicy(address(controller));
        Vm.Wallet memory reservedBuyer = vm.createWallet("reservedBuyer");
        token.mint(reservedBuyer.addr, 1_000 ether);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        NamespaceTypes.ModuleConfig[] memory policies = new NamespaceTypes.ModuleConfig[](3);
        policies[0] = config.policies[0];
        policies[1] = config.policies[1];

        ReservationPolicy.ReservationInput[] memory reservations = new ReservationPolicy.ReservationInput[](1);
        reservations[0] = ReservationPolicy.ReservationInput({
            labelHash: keccak256(bytes("vip")), account: reservedBuyer.addr, expiry: uint64(block.timestamp + 1 days)
        });
        policies[2] = NamespaceTypes.ModuleConfig({
            module: address(reservationPolicy),
            configData: abi.encode(ReservationPolicy.Params({reservations: reservations}))
        });
        config.policies = policies;

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.policyData = new bytes[](3);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationPolicy.ReservedLabel.selector,
                activationId,
                "vip",
                reservedBuyer.addr,
                uint64(block.timestamp + 1 days),
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

    function _approveDefaultModules() private {
        _approveModule(address(saleWindowPolicy));
        _approveModule(address(labelLengthPolicy));
        _approveModule(address(fixedPricePricing));
        _approveModule(address(erc20Payment));
        _approveModule(address(noopProcessor));
        _approveModule(address(postHook));
    }

    function _approveModule(address module) private {
        vm.expectEmit(true, false, false, true, address(controller));
        emit ModuleApprovalSet(module, true);
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(module, true);
    }
}
