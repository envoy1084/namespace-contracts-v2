// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {SetAddrToBuyerHook} from "src/modules/hooks/SetAddrToBuyerHook.sol";
import {MockAddrResolver} from "test/mocks/MockAddrResolver.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract SetAddrToBuyerHookTest is NamespaceSetUp {
    SetAddrToBuyerHook internal hook;
    MockAddrResolver internal resolver;

    function setUp() public override {
        super.setUp();
        hook = new SetAddrToBuyerHook(address(controller));
        resolver = new MockAddrResolver();
    }

    function test_afterMint_setsAddrToBuyer() public {
        bytes32 parentNode = keccak256("alice.eth");
        bytes32 labelHash = keccak256("pay");
        bytes32 node = keccak256(abi.encodePacked(parentNode, labelHash));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = parentNode;
        ctx.labelHash = labelHash;
        ctx.resolver = address(resolver);

        vm.prank(address(controller));
        hook.afterMint(ctx, 1, "");

        assertEq(resolver.addrs(node), accounts.buyer.addr);
    }

    function test_afterMint_allowsAddressOverride() public {
        bytes32 parentNode = keccak256("alice.eth");
        bytes32 labelHash = keccak256("pay");
        bytes32 node = keccak256(abi.encodePacked(parentNode, labelHash));
        address overrideAddress = address(0xCAFE);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = keccak256("activation");
        ctx.buyer = accounts.buyer.addr;
        ctx.parentNode = parentNode;
        ctx.labelHash = labelHash;
        ctx.resolver = address(resolver);

        vm.prank(address(controller));
        hook.afterMint(ctx, 1, abi.encode(overrideAddress));

        assertEq(resolver.addrs(node), overrideAddress);
    }
}
