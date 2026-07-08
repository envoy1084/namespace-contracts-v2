# ENSv2 Update Notes: 5677359 -> 48b3e2d

This note records the Namespace-facing changes after updating `lib/contracts-v2` from `5677359db15edd8b7e2a7cda4798d801ab129c9d` to `48b3e2d39513b9dd32ef1850877a29009bc807b9`.

## Build Impact

Namespace still builds and tests against the updated ENSv2 source after fixture updates.

Current verification:

```sh
forge build
forge lint
forge test
./scripts/generate-benchmarks.sh
```

## Important ENSv2 Contract Changes

### Registry Constructor Changed

`PermissionedRegistry` no longer takes an HCA factory and metadata provider.

Current constructor:

```solidity
constructor(ILabelStore labelStore, address rootAccount, uint256 roleBitmap)
```

Namespace fixtures now deploy one shared `LabelStore` and pass it to root, `.eth`, and namespace registries.

### HCA Sources Removed

The old HCA helper contracts were removed:

- `src/hca/HCAContext.sol`
- `src/hca/HCAContextUpgradeable.sol`
- `src/hca/HCAEquivalence.sol`
- `src/hca/interfaces/IHCAFactoryBasic.sol`

Namespace tests no longer import `IHCAFactoryBasic`.

### External Registry Metadata Providers Removed

The previous metadata provider contracts were removed:

- `src/registry/MetadataMixin.sol`
- `src/registry/SimpleRegistryMetadata.sol`
- `src/registry/BaseUriRegistryMetadata.sol`
- `src/registry/interfaces/IRegistryMetadata.sol`

The updated registry path uses `LabelStore` plus built-in URI fields/rendering hooks.

### New Label And Naming Utilities

Added:

- `src/utils/LabelStore.sol`
- `src/utils/interfaces/ILabelStore.sol`
- `src/utils/ContractNamer.sol`
- `src/utils/DelegatedContractNamer.sol`
- `src/reverse-registrar/interfaces/IContractNamer.sol`

Namespace currently needs `LabelStore` in tests because the registry constructor requires it.

### Registry Interfaces Expanded

Added:

- `IOwnedRegistry`
- `ITemporalRegistry`
- `ITokenizedRegistry`
- `IRegistryURIRenderer`

`PermissionedRegistry` now advertises a broader interface set around ownership lookup, temporal expiry/renewal, tokenized ownership, and URI rendering.

### Resolver Changes

`PermissionedResolver` constructor and initializer changed.

Current constructor:

```solidity
constructor(address namer)
```

Current initializer:

```solidity
function initialize(address admin, uint256 roleBitmap, bytes[] calldata setters)
```

Namespace resolver hook tests now pass an empty `bytes[] setters` array during proxy initialization.

### Universal Resolver Interface Added Upstream

ENSv2 now includes:

- `src/universalResolver/interfaces/IUniversalResolverV2.sol`

Important functions:

- `findOwner(bytes name)`
- `findCanonicalName(IRegistry registry)`
- `findCanonicalRegistry(bytes name)`
- `findExactRegistry(bytes name)`
- `findParentRegistry(bytes name)`
- `findRegistries(bytes name)`

Namespace still keeps a local minimal interface because the controller also calls the public immutable `ROOT_REGISTRY()` getter on the implementation/proxy.

### Public Resolver Added

Added:

- `src/resolver/PublicResolverV2.sol`

This does not change Namespace execution directly, but it matters for deployment choices and resolver UX.

## Sepolia Deployment Addresses Used By Namespace

Source: `lib/contracts-v2/contracts/docs/addresses/sepolia.md`.

| ENSv2 contract | Address |
| --- | --- |
| UpgradableUniversalResolverProxy | `0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe` |
| ManagedUniversalResolverProxy | `0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1` |
| UniversalResolverV2 | `0x85eDf8B6b7D4211e2b07AA687506B746357B92cf` |
| RootRegistry | `0x11b5bfbe9078d826b1edbdd1cfc12f5828d9f50c` |
| ETHRegistry | `0x67b728a792e789a8978b30cf1b3b641f19354b43` |
| LabelStore | `0xb03524289c16424f71802a1794c29c7bd1b9f577` |

The Namespace `DeploySepolia` script is Sepolia-only and uses the top UniversalResolver proxy directly.
