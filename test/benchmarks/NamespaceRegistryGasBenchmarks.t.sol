// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";

import {NamespaceBenchmarkProfiles} from "test/benchmarks/common/NamespaceBenchmarkProfiles.sol";

/// @notice Direct ENSv2 PermissionedRegistry baselines that show the registry-backed gas floor.
contract NamespaceRegistryGasBenchmarks is NamespaceBenchmarkProfiles {
    uint256 internal renewTokenId;

    function setUp() public override {
        super.setUp();

        vm.prank(address(controller));
        renewTokenId = registry.register(
            "renew-direct", accounts.buyer.addr, IRegistry(address(0)), address(0), BUYER_ROLES, _expiry()
        );
    }

    function testBenchmark_registry_00_registerNoRolesNoResolver() public {
        vm.prank(address(controller));
        registry.register("direct-00", accounts.buyer.addr, IRegistry(address(0)), address(0), 0, _expiry());
    }

    function testBenchmark_registry_01_registerBuyerRolesNoResolver() public {
        vm.prank(address(controller));
        registry.register("direct-01", accounts.buyer.addr, IRegistry(address(0)), address(0), BUYER_ROLES, _expiry());
    }

    function testBenchmark_registry_02_registerBuyerRolesWithResolver() public {
        vm.prank(address(controller));
        registry.register(
            "direct-02", accounts.buyer.addr, IRegistry(address(0)), address(resolver), BUYER_ROLES, _expiry()
        );
    }

    function testBenchmark_registry_03_reserveLabelNoOwner() public {
        vm.prank(address(controller));
        registry.register("reserved", address(0), IRegistry(address(0)), address(0), 0, _expiry());
    }

    function testBenchmark_registry_04_renewRegistered() public {
        vm.prank(address(controller));
        registry.renew(renewTokenId, _expiry() + 30 days);
    }

    function _expiry() private view returns (uint64) {
        return uint64(block.timestamp + 365 days);
    }
}
