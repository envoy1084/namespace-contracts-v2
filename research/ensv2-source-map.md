# ENSv2 Source Map

Use this as a quick reference from concept to source file.

## Registry System

| File | Purpose |
| --- | --- |
| `lib/contracts-v2/contracts/src/registry/interfaces/IRegistry.sol` | Minimal traversal interface: `getSubregistry`, `getResolver`, `getParent`. |
| `lib/contracts-v2/contracts/src/registry/interfaces/IStandardRegistry.sol` | Standard registry mutations: `register`, `renew`, `unregister`, `setSubregistry`, `setResolver`, `setParent`. |
| `lib/contracts-v2/contracts/src/registry/interfaces/IPermissionedRegistry.sol` | Status, state, resource id, token id helpers. |
| `lib/contracts-v2/contracts/src/registry/interfaces/IRegistryEvents.sol` | Registry events. |
| `lib/contracts-v2/contracts/src/registry/PermissionedRegistry.sol` | Main registry implementation. Start here. |
| `lib/contracts-v2/contracts/src/registry/UserRegistry.sol` | UUPS upgradeable registry for user-owned namespaces. |
| `lib/contracts-v2/contracts/src/registry/libraries/RegistryRolesLib.sol` | Registry role constants. |
| `lib/contracts-v2/contracts/src/registry/MetadataMixin.sol` | Delegates token URI to metadata provider. |
| `lib/contracts-v2/contracts/src/registry/SimpleRegistryMetadata.sol` | Per-token metadata URI provider. |
| `lib/contracts-v2/contracts/src/registry/BaseUriRegistryMetadata.sol` | Shared base URI metadata provider. |

## Token And Access Control

| File | Purpose |
| --- | --- |
| `lib/contracts-v2/contracts/src/erc1155/ERC1155Singleton.sol` | ERC1155 variant with one owner per token id. |
| `lib/contracts-v2/contracts/src/erc1155/interfaces/IERC1155Singleton.sol` | ERC1155 singleton interface. |
| `lib/contracts-v2/contracts/src/access-control/EnhancedAccessControl.sol` | Resource-scoped bitmap role system. |
| `lib/contracts-v2/contracts/src/access-control/interfaces/IEnhancedAccessControl.sol` | EAC external interface and errors/events. |
| `lib/contracts-v2/contracts/src/access-control/libraries/EACBaseRolesLib.sol` | Generic role bitmap constants. |
| `lib/contracts-v2/contracts/src/utils/LibLabel.sol` | Label hash and version-bit helpers. |

## Dot ETH Registrar And Pricing

| File | Purpose |
| --- | --- |
| `lib/contracts-v2/contracts/src/registrar/ETHRegistrar.sol` | Commit-reveal `.eth` registrar and renewal controller. |
| `lib/contracts-v2/contracts/src/registrar/interfaces/IETHRegistrar.sol` | Registrar events, errors, and public interface. |
| `lib/contracts-v2/contracts/src/registrar/StandardRentPriceOracle.sol` | Length-based price, duration discount, premium, ERC20 ratios. |
| `lib/contracts-v2/contracts/src/registrar/interfaces/IRentPriceOracle.sol` | Pricing oracle interface. |
| `lib/contracts-v2/contracts/src/registrar/libraries/LibHalving.sol` | Premium decay math. |
| `lib/contracts-v2/contracts/src/registrar/BatchRegistrar.sol` | Batch reservation helper used by deployments and setup flows. |

## Resolution

| File | Purpose |
| --- | --- |
| `lib/contracts-v2/contracts/src/universalResolver/UniversalResolverV2.sol` | ENSv2 universal resolver. |
| `lib/contracts-v2/contracts/src/universalResolver/libraries/LibRegistry.sol` | Registry tree traversal and canonical registry helpers. |
| `lib/contracts-v2/contracts/src/resolver/PermissionedResolver.sol` | Upgradeable permissioned resolver supporting common records. |
| `lib/contracts-v2/contracts/src/resolver/interfaces/IPermissionedResolver.sol` | Permissioned resolver interface. |
| `lib/contracts-v2/contracts/src/resolver/libraries/PermissionedResolverLib.sol` | Resolver role constants and resource helpers. |
| `lib/contracts-v2/contracts/src/resolver/libraries/ResolverProfileRewriterLib.sol` | Rewrites resolver calldata during alias resolution. |

## User Registry Deployment And Tests

| File | Purpose |
| --- | --- |
| `lib/contracts-v2/contracts/deploy/00_RootRegistry.ts` | Deploys root registry. |
| `lib/contracts-v2/contracts/deploy/01_ETHRegistry.ts` | Deploys `.eth` registry and registers `eth` in root. |
| `lib/contracts-v2/contracts/deploy/03_ETHRegistrar.ts` | Deploys `.eth` registrar and grants registry root roles. |
| `lib/contracts-v2/contracts/deploy/01_UserRegistryImpl.ts` | Deploys `UserRegistry` implementation. |
| `lib/contracts-v2/contracts/deploy/01_PermissionedResolverImpl.ts` | Deploys resolver implementation. |
| `lib/contracts-v2/contracts/script/deploy-constants.ts` | Role constants and deployment role bitmaps. |
| `lib/contracts-v2/contracts/test/integration/fixtures/deployV2Fixture.ts` | Compact deployment fixture showing the system assembled. |
| `lib/contracts-v2/contracts/test/unit/registry/PermissionedRegistry.t.sol` | Registry behavior tests. |
| `lib/contracts-v2/contracts/test/unit/registrar/ETHRegistrar.t.sol` | Registrar behavior tests. |
| `lib/contracts-v2/contracts/test/unit/resolver/PermissionedResolver.t.sol` | Resolver behavior tests. |

## HCA Support

| File | Purpose |
| --- | --- |
| `lib/contracts-v2/contracts/src/hca/HCAEquivalence.sol` | Resolves Hidden Contract Account caller to owner. |
| `lib/contracts-v2/contracts/src/hca/HCAContext.sol` | Non-upgradeable HCA-aware `_msgSender()`. |
| `lib/contracts-v2/contracts/src/hca/HCAContextUpgradeable.sol` | Upgradeable HCA-aware `_msgSender()`. |
| `lib/contracts-v2/contracts/src/hca/interfaces/IHCAFactoryBasic.sol` | Minimal HCA factory interface. |

