// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {RegistryRolesLib} from "@ensv2/registry/libraries/RegistryRolesLib.sol";
import {PermissionedRegistry} from "@ensv2/registry/PermissionedRegistry.sol";
import {SimpleRegistryMetadata} from "@ensv2/registry/SimpleRegistryMetadata.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {LabelLengthPolicy} from "src/modules/policies/LabelLengthPolicy.sol";
import {SaleWindowPolicy} from "src/modules/policies/SaleWindowPolicy.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {MockENSV2HCAFactoryBasic} from "test/mocks/MockENSV2HCAFactoryBasic.sol";

contract NamespacePermissionedRegistryE2ETest is NamespaceSetUp {
    MockENSV2HCAFactoryBasic internal hcaFactory;
    SimpleRegistryMetadata internal metadata;
    PermissionedRegistry internal permissionedRegistry;

    function setUp() public override {
        super.setUp();

        hcaFactory = new MockENSV2HCAFactoryBasic();
        metadata = new SimpleRegistryMetadata(hcaFactory);
        permissionedRegistry = new PermissionedRegistry(
            hcaFactory,
            metadata,
            address(this),
            RegistryRolesLib.ROLE_REGISTRAR_ADMIN | RegistryRolesLib.ROLE_RENEW_ADMIN
                | RegistryRolesLib.ROLE_REGISTER_RESERVED_ADMIN
        );

        permissionedRegistry.grantRootRoles(RegistryRolesLib.ROLE_REGISTRAR_ADMIN, accounts.alice.addr);
        permissionedRegistry.grantRootRoles(
            RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_RENEW, address(controller)
        );
    }

    function test_mintAndRenewThroughRealPermissionedRegistry() public {
        NamespaceTypes.ActivationConfig memory config = _permissionedRegistryActivationConfig();

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 150 ether);
        uint256 tokenId = controller.mint(activationId, "real", 365 days, runtimeData);

        IPermissionedRegistry.State memory beforeRenew =
            permissionedRegistry.getState(uint256(keccak256(bytes("real"))));
        uint64 newExpiry = controller.renew(activationId, "real", 30 days, runtimeData);
        vm.stopPrank();

        IPermissionedRegistry.State memory afterRenew = permissionedRegistry.getState(tokenId);
        assertEq(permissionedRegistry.ownerOf(tokenId), accounts.buyer.addr);
        assertEq(permissionedRegistry.getResolver("real"), address(0xBEEF));
        assertEq(address(permissionedRegistry.getSubregistry("real")), address(0));
        assertTrue(permissionedRegistry.hasRoles(tokenId, BUYER_ROLES, accounts.buyer.addr));
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
                FixedPricePricing.Params({token: address(token), mintAmount: 100 ether, renewAmount: 50 ether})
            )
        });

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});

        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(permissionedRegistry)),
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
