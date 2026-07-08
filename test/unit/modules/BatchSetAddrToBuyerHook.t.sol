// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {PermissionedResolver} from "@ensv2/resolver/PermissionedResolver.sol";
import {VerifiableFactory} from "lib/contracts-v2/contracts/lib/verifiable-factory/src/VerifiableFactory.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {BatchSetAddrToBuyerHook} from "src/modules/hooks/BatchSetAddrToBuyerHook.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract BatchSetAddrToBuyerHookTest is NamespaceSetUp {
    BatchSetAddrToBuyerHook internal hook;
    PermissionedResolver internal resolver;

    function setUp() public override {
        super.setUp();
        hook = BatchSetAddrToBuyerHook(_deployModule(address(new BatchSetAddrToBuyerHook())));
        resolver = _deployResolver(address(hook), PermissionedResolverLib.ROLE_SET_ADDR);
    }

    function test_afterMint_setsAddrToBuyerWhenRuntimeDataIsEmpty() public {
        bytes32 parentNode = keccak256("alice.eth");
        bytes32 labelHash = keccak256("pay");
        bytes32 node = _childNode(parentNode, labelHash);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = parentNode;
        ctx.labelHash = labelHash;
        ctx.resolver = address(resolver);

        vm.prank(address(controller));
        hook.afterMint(ctx, 1, "");

        assertEq(resolver.addr(node), accounts.buyer.addr);
    }

    function test_afterMint_setsPackedOverridesInOrder() public {
        bytes32 parentNode = keccak256("alice.eth");
        bytes32 labelHash = keccak256("pay");
        bytes32 node = _childNode(parentNode, labelHash);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = parentNode;
        ctx.labelHash = labelHash;
        ctx.resolver = address(resolver);

        bytes memory runtimeData = abi.encodePacked(address(0), accounts.alice.addr, accounts.treasury.addr);

        vm.prank(address(controller));
        hook.afterMint(ctx, 1, runtimeData);

        assertEq(resolver.addr(node), accounts.treasury.addr);
    }

    function test_afterMint_revertsForMalformedPackedOverrides() public {
        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = keccak256("alice.eth");
        ctx.labelHash = keccak256("pay");
        ctx.resolver = address(resolver);

        vm.expectRevert(abi.encodeWithSelector(BatchSetAddrToBuyerHook.InvalidRuntimeDataLength.selector, 21));
        vm.prank(address(controller));
        hook.afterMint(ctx, 1, new bytes(21));
    }

    function test_configureAndAfterRenewAreControllerOnlyNoOps() public {
        vm.prank(address(controller));
        hook.configure(keccak256("activation"), "");

        NamespaceTypes.RenewContext memory ctx;
        vm.prank(address(controller));
        hook.afterRenew(ctx, "");
    }

    function test_afterMint_revertsWhenResolverMissing() public {
        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = keccak256("alice.eth");
        ctx.labelHash = keccak256("pay");

        vm.expectRevert(
            abi.encodeWithSelector(BatchSetAddrToBuyerHook.ResolverNotConfigured.selector, ctx.activationId)
        );
        vm.prank(address(controller));
        hook.afterMint(ctx, 1, "");
    }

    function _deployResolver(address admin, uint256 roles) private returns (PermissionedResolver) {
        VerifiableFactory factory = new VerifiableFactory();
        PermissionedResolver resolverImpl = new PermissionedResolver(admin);
        bytes[] memory setters = new bytes[](0);
        bytes memory initData = abi.encodeCall(PermissionedResolver.initialize, (admin, roles, setters));
        return PermissionedResolver(factory.deployProxy(address(resolverImpl), uint256(keccak256(initData)), initData));
    }

    function _childNode(bytes32 parentNode, bytes32 labelHash) private pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, parentNode)
            mstore(add(ptr, 0x20), labelHash)
            result := keccak256(ptr, 0x40)
        }
    }
}
