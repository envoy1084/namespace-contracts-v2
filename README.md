# Namespace Contracts V2

Namespace Contracts V2 is an activation-based ENSv2 subname sale controller.

It lets a parent-name owner configure ordered rules, one payment module, and optional post hooks for subname minting and renewal. ENSv2 `PermissionedRegistry` remains the source of truth for ownership, expiry, resolver, roles, and registry permissions.

## Documentation Index

Read the technical spec in this order:

1. [System Overview](./docs/01-system-overview.md) - end-to-end model, actors, contract groups, runtime pipeline.
2. [Architecture Decisions](./docs/02-architecture-decisions.md) - why activations, unified rules, strict phases, one payment module, and official ENSv2 registries are used.
3. [ENSv2 Integration And Permissions](./docs/03-ensv2-integration-and-permissions.md) - registry boundary, roles, parent validation, direct bypass risk.
4. [Data Model And Storage](./docs/04-data-model-and-storage.md) - activation ids, structs, compact module-list storage, contexts, label binding.
5. [Activation Lifecycle](./docs/05-activation-lifecycle.md) - zero-to-one setup, activation checks, config updates, status, ownership transfer.
6. [Mint Flow](./docs/06-mint-flow.md) - exact `mint` execution path with flowchart, sequence diagram, checks, payment, hooks.
7. [Renewal Flow](./docs/07-renewal-flow.md) - exact `renew` execution path, registry state checks, activation binding, payment, hooks.
8. [Rule Engine](./docs/08-rule-engine.md) - phase matrix, decisions, flags, price operations, token consistency.
9. [Rule Modules](./docs/09-rule-modules.md) - every shipped rule, config ABI, runtime data, checks, output, phase placement.
10. [Payment Modules](./docs/10-payment-modules.md) - native, ERC20, and ERC20 split settlement behavior.
11. [Post Hooks And Resolvers](./docs/11-post-hooks-and-resolvers.md) - resolver hooks, runtime data, node calculation, hook risks.
12. [Extension Guide](./docs/12-extension-guide.md) - how to add future rules, payment modules, hooks, and integrations.
13. [Security And Operations](./docs/13-security-and-operations.md) - deployment, admin risks, claims, oracle/payment safety, incident response.
14. [Example Sale Blueprints](./docs/14-example-sale-blueprints.md) - concrete module stacks and user flows.
15. [Contract Reference](./docs/15-contract-reference.md) - API, events, types, modules, and error categories.
16. [Activation Interface Recommendations](./docs/16-activation-interface-recommendations.md) - `IPermissionedRegistry` versus `IStandardRegistry`, one-current-activation design, and Universal Resolver activation UX.

Research and benchmark references:

| File | Purpose |
| --- | --- |
| [Architecture Decision History](./research/architecture-decision-history.md) | Prior design decisions and module-architecture history. |
| [Architecture And Gas Review](./research/namespace-architecture-gas-review.md) | Architecture and gas tradeoff review. |
| [Strict Effect Architecture Research](./research/strict-effect-architecture-research.md) | Research behind the strict phased rule engine. |
| [ENSv2 Research Index](./research/ensv2-research-index.md) | Upstream ENSv2 contract research. |
| [BENCHMARKS.md](./benchmarks/BENCHMARKS.md) | Benchmark index and generation command. |
| [PROFILE_BENCHMARKS.md](./benchmarks/PROFILE_BENCHMARKS.md) | Profile gas benchmarks. |
| [SCENARIO_BENCHMARKS.md](./benchmarks/SCENARIO_BENCHMARKS.md) | Scenario gas benchmarks. |

## Contract Groups

| Group | Path | Purpose |
| --- | --- | --- |
| Controller | `src/NamespaceController.sol` and `src/controller/` | Activation lifecycle, rule evaluation, ENSv2 mint/renew calls, payment dispatch, hooks. |
| Shared types | `src/libraries/NamespaceTypes.sol` | Activation config, runtime data, contexts, price, rule output, phases. |
| Interfaces | `src/interfaces/` | Controller, module, resolver, and oracle interfaces. |
| Base modules | `src/modules/NamespaceModule.sol`, `src/modules/rules/NamespaceRule.sol` | Controller-only module base and rule helper. |
| Rules | `src/modules/rules/` | Pause, sale window, length, token balance, fixed price, length premium, class, USD oracle, reservation, whitelist. |
| Payment | `src/modules/payment/` | Native payment, ERC20 payment, ERC20 split payment. |
| Hooks | `src/modules/hooks/` | Post-mint resolver address hooks. |

## Common Commands

```sh
forge test
forge lint
forge fmt --check
forge coverage --exclude-tests --summary
solhint 'src/**/*.sol' 'test/**/*.sol'
./scripts/slither-build.sh && slither .
./scripts/generate-benchmarks.sh
```

Coverage gates should use `--exclude-tests`. The target is 100% coverage for production contracts in `src/`; mocks, benchmark helpers, and tests are not part of that gate.

## Deployment

Deploy Namespace controller and all current production modules with Forge:

```sh
export PRIVATE_KEY=<deployer-key>
export SEPOLIA_RPC_URL=<rpc-url>

forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast
```

`DeploySepolia` is intentionally Sepolia-only. It reverts on other chain ids, makes the deployer the controller and module owner, and uses the ENSv2 Sepolia addresses from `lib/contracts-v2/contracts/docs/addresses/sepolia.md`.

## Benchmark Artifacts

Gas benchmarks live under `test/benchmarks/`, with controller slice probes under `test/profile/`, and are regenerated by:

```sh
./scripts/generate-benchmarks.sh
```

Generated outputs:

| File | Description |
| --- | --- |
| `benchmarks/BENCHMARKS.md` | Benchmark index. |
| `benchmarks/PROFILE_BENCHMARKS.md` | Profile-level gas report. |
| `benchmarks/SCENARIO_BENCHMARKS.md` | End-to-end scenario gas report. |
| `benchmarks/gas-components.tsv` | Machine-readable component inputs. |
| `benchmarks/profile-gas-report.json` | Machine-readable profile report. |

Interactive calculator:

```sh
./scripts/calculate-gas.py interactive
```
