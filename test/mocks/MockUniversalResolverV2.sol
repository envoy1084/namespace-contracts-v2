// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {LibRegistry} from "@ensv2/universalResolver/libraries/LibRegistry.sol";

import {IUniversalResolverV2} from "src/interfaces/IUniversalResolverV2.sol";

/// @notice Test-only UniversalResolverV2 stand-in that reuses ENSv2 registry traversal logic.
contract MockUniversalResolverV2 is IUniversalResolverV2 {
    IRegistry public immutable ROOT_REGISTRY;
    IRegistry private canonicalRegistryOverride;
    bool private useCanonicalRegistryOverride;
    IRegistry[] private registriesOverride;
    bool private useRegistriesOverride;

    constructor(IRegistry rootRegistry) {
        ROOT_REGISTRY = rootRegistry;
    }

    function findCanonicalName(IRegistry registry) external view returns (bytes memory name) {
        return LibRegistry.findCanonicalName(ROOT_REGISTRY, registry);
    }

    function findCanonicalRegistry(bytes calldata name) external view returns (IRegistry registry) {
        if (useCanonicalRegistryOverride) {
            return canonicalRegistryOverride;
        }
        return LibRegistry.findCanonicalRegistry(ROOT_REGISTRY, name);
    }

    function findExactRegistry(bytes calldata name) external view returns (IRegistry registry) {
        return LibRegistry.findExactRegistry(ROOT_REGISTRY, name, 0);
    }

    function findRegistries(bytes calldata name) external view returns (IRegistry[] memory registries) {
        if (useRegistriesOverride) {
            return registriesOverride;
        }
        return LibRegistry.findRegistries(ROOT_REGISTRY, name, 0);
    }

    function findResolver(bytes memory name) external view returns (address resolver, bytes32 node, uint256 offset) {
        (, resolver, node, offset) = LibRegistry.findResolver(ROOT_REGISTRY, name, 0);
    }

    function setCanonicalRegistryOverride(IRegistry registry) external {
        canonicalRegistryOverride = registry;
        useCanonicalRegistryOverride = true;
    }

    function setRegistriesOverride(IRegistry[] memory registries) external {
        delete registriesOverride;
        uint256 length = registries.length;
        for (uint256 i; i < length;) {
            registriesOverride.push(registries[i]);
            unchecked {
                ++i;
            }
        }
        useRegistriesOverride = true;
    }

    function clearOverrides() external {
        canonicalRegistryOverride = IRegistry(address(0));
        useCanonicalRegistryOverride = false;
        delete registriesOverride;
        useRegistriesOverride = false;
    }
}
