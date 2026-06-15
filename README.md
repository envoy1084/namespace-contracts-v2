# Namespace Contracts V2

Namespace Contracts V2 is an activation-based ENSv2 subname minting layer.

It lets a namespace owner configure a subname sale with policies, pricing, payment collection, revenue processing, and post-mint hooks, while keeping the official ENSv2 `PermissionedRegistry` as the source of truth for ownership, expiry, resolver, and permissions.

## Recommended Reading Order

1. [Namespace Contracts Overview](./docs/01-overview.md)
2. [Activation And Configuration](./docs/02-activation-and-configuration.md)
3. [Mint And Renewal Flow](./docs/03-mint-and-renewal-flow.md)
4. [Module Catalog](./docs/04-module-catalog.md)
5. [Contract Reference](./docs/05-contract-reference.md)
6. [Security And Operations](./docs/06-security-and-operations.md)
7. [Gas Benchmarks](./BENCHMARKS.md)
8. [ENSv2 Research Index](./research/ensv2-research-index.md)

## Contract Groups

| Group | Path | Purpose |
| --- | --- | --- |
| Controller | `src/NamespaceController.sol` | Activation, mint, renew, registry orchestration. |
| Shared types | `src/libraries/NamespaceTypes.sol` | Common config, context, runtime, and price structs. |
| Interfaces | `src/interfaces/` | Module and integration interfaces. |
| Base module | `src/modules/NamespaceModule.sol` | Controller-only module base. |
| Policies | `src/modules/policies/` | Sale windows, label length, token gates, reservations, whitelists. |
| Pricing | `src/modules/pricing/` | Fixed, length-based, and USD oracle pricing. |
| Payment | `src/modules/payment/` | ERC20 collection. |
| Processors | `src/modules/processors/` | No-op and ERC20 split settlement. |
| Hooks | `src/modules/hooks/` | Post-mint resolver updates. |

## Common Commands

```sh
forge test
forge lint
solhint 'src/**/*.sol' 'test/**/*.sol'
./scripts/slither-build.sh && slither .
./scripts/generate-benchmarks.sh
```

## Benchmarks

Gas benchmarks live in `test/benchmarks/`.

Regenerate the root benchmark report with:

```sh
./scripts/generate-benchmarks.sh
```

The generated report is [BENCHMARKS.md](./BENCHMARKS.md).

## Research

The `research/` folder contains the earlier ENSv2 contract research and architecture notes. Those docs explain the upstream ENSv2 registry, permissions, resolution, and `.eth` flows that Namespace builds on top of.

