// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";

/// @title IUniversalResolverV2
/// @notice Minimal ENSv2 UniversalResolver surface used by Namespace activation.
interface IUniversalResolverV2 {
    function ROOT_REGISTRY() external view returns (IRegistry);

    function findCanonicalName(IRegistry registry) external view returns (bytes memory name);

    function findCanonicalRegistry(bytes calldata name) external view returns (IRegistry registry);

    function findExactRegistry(bytes calldata name) external view returns (IRegistry registry);

    function findRegistries(bytes calldata name) external view returns (IRegistry[] memory registries);

    function findResolver(bytes memory name) external view returns (address resolver, bytes32 node, uint256 offset);
}
