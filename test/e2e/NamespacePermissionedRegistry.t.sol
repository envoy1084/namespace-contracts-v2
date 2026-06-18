// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespacePermissionedRegistryE2ETest is NamespaceSetUp {
    function test_mintAndRenewThroughRealPermissionedRegistry() public {
        bytes32 activationId = _activateDefault();
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
}
