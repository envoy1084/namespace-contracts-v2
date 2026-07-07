// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";
import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {PermissionedResolver} from "@ensv2/resolver/PermissionedResolver.sol";
import {VerifiableFactory} from "lib/contracts-v2/contracts/lib/verifiable-factory/src/VerifiableFactory.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {SetAddrToBuyerHook} from "src/modules/hooks/SetAddrToBuyerHook.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract SetAddrToBuyerHookTest is NamespaceSetUp {
    SetAddrToBuyerHook internal hook;
    PermissionedResolver internal resolver;

    function setUp() public override {
        super.setUp();
        hook = SetAddrToBuyerHook(_deployModule(address(new SetAddrToBuyerHook())));
        resolver = _deployResolver(address(hook), PermissionedResolverLib.ROLE_SET_ADDR);
    }

    function test_afterMint_setsAddrToBuyer() public {
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

    function test_afterMint_allowsAddressOverride() public {
        bytes32 parentNode = keccak256("alice.eth");
        bytes32 labelHash = keccak256("pay");
        bytes32 node = _childNode(parentNode, labelHash);
        address overrideAddress = address(0xCAFE);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = parentNode;
        ctx.labelHash = labelHash;
        ctx.resolver = address(resolver);

        vm.prank(address(controller));
        hook.afterMint(ctx, 1, abi.encode(overrideAddress));

        assertEq(resolver.addr(node), overrideAddress);
    }

    function test_configureAndAfterRenewAreControllerOnlyNoOps() public {
        vm.prank(address(controller));
        hook.configure(keccak256("activation"), "");

        NamespaceTypes.RenewContext memory ctx;
        vm.prank(address(controller));
        hook.afterRenew(ctx, "");
    }

    function test_afterMint_revertsWhenResolverMissingOrRuntimeMalformed() public {
        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = keccak256("alice.eth");
        ctx.labelHash = keccak256("pay");

        vm.expectRevert(abi.encodeWithSelector(SetAddrToBuyerHook.ResolverNotConfigured.selector, ctx.activationId));
        vm.prank(address(controller));
        hook.afterMint(ctx, 1, "");

        ctx.resolver = address(resolver);
        vm.expectRevert(abi.encodeWithSelector(SetAddrToBuyerHook.InvalidRuntimeDataLength.selector, 1));
        vm.prank(address(controller));
        hook.afterMint(ctx, 1, hex"aa");
    }

    function _deployResolver(address admin, uint256 roles) private returns (PermissionedResolver) {
        VerifiableFactory factory = new VerifiableFactory();
        PermissionedResolver resolverImpl = new PermissionedResolver(IHCAFactoryBasic(address(0)));
        bytes memory initData = abi.encodeCall(PermissionedResolver.initialize, (admin, roles));
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
