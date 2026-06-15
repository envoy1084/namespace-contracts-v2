// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";

contract NamespaceControllerTest is NamespaceSetUp {
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
}
