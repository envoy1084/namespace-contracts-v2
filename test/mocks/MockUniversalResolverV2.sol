// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IUniversalResolverV2} from "@ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";
import {LibRegistry} from "@ensv2/universalResolver/libraries/LibRegistry.sol";

/// @notice Test-only UniversalResolverV2 stand-in that reuses ENSv2 registry traversal logic.
contract MockUniversalResolverV2 is IUniversalResolverV2 {
    IRegistry public immutable ROOT_REGISTRY;
    IRegistry private exactRegistryOverride;
    bool private useExactRegistryOverride;

    constructor(IRegistry rootRegistry) {
        ROOT_REGISTRY = rootRegistry;
    }

    function findCanonicalName(IRegistry registry) external view returns (bytes memory name) {
        return LibRegistry.findCanonicalName(ROOT_REGISTRY, registry);
    }

    function findOwner(bytes calldata name) external view returns (address owner) {
        return LibRegistry.findOwner(ROOT_REGISTRY, name, 0);
    }

    function findCanonicalRegistry(bytes calldata name) external view returns (IRegistry registry) {
        return LibRegistry.findCanonicalRegistry(ROOT_REGISTRY, name);
    }

    function findExactRegistry(bytes calldata name) external view returns (IRegistry registry) {
        if (useExactRegistryOverride) {
            return exactRegistryOverride;
        }
        return LibRegistry.findExactRegistry(ROOT_REGISTRY, name, 0);
    }

    function findParentRegistry(bytes calldata name) external view returns (IRegistry registry) {
        return LibRegistry.findParentRegistry(ROOT_REGISTRY, name, 0);
    }

    function findRegistries(bytes calldata name) external view returns (IRegistry[] memory registries) {
        return LibRegistry.findRegistries(ROOT_REGISTRY, name, 0);
    }

    function findResolver(bytes memory name) external view returns (address resolver, bytes32 node, uint256 offset) {
        (, resolver, node, offset) = LibRegistry.findResolver(ROOT_REGISTRY, name, 0);
    }

    function setExactRegistryOverride(IRegistry registry) external {
        exactRegistryOverride = registry;
        useExactRegistryOverride = true;
    }

    function clearOverrides() external {
        exactRegistryOverride = IRegistry(address(0));
        useExactRegistryOverride = false;
    }
}
