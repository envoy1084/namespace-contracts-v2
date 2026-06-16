// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {LabelLengthPolicy} from "src/modules/policies/LabelLengthPolicy.sol";
import {SaleWindowPolicy} from "src/modules/policies/SaleWindowPolicy.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespacePermissionedRegistryE2ETest is NamespaceSetUp {
    function test_mintAndRenewThroughRealPermissionedRegistry() public {
        NamespaceTypes.ActivationConfig memory config = _permissionedRegistryActivationConfig();

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 150 ether);
        uint256 tokenId = controller.mint(activationId, "real", 365 days, runtimeData);

        IPermissionedRegistry.State memory beforeRenew = registry.getState(uint256(keccak256(bytes("real"))));
        uint64 newExpiry = controller.renew(activationId, "real", 30 days, runtimeData);
        vm.stopPrank();

        IPermissionedRegistry.State memory afterRenew = registry.getState(tokenId);
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
        assertEq(registry.getResolver("real"), address(0xBEEF));
        assertEq(address(registry.getSubregistry("real")), address(0));
        assertTrue(registry.hasRoles(tokenId, BUYER_ROLES, accounts.buyer.addr));
        assertEq(uint256(beforeRenew.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(beforeRenew.tokenId, tokenId);
        assertEq(newExpiry, beforeRenew.expiry + 30 days);
        assertEq(afterRenew.expiry, newExpiry);
        assertEq(token.balanceOf(accounts.treasury.addr), 150 ether);
    }

    function _permissionedRegistryActivationConfig()
        private
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
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
}
