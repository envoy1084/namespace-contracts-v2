# Namespace Scenario Gas Benchmarks

Scenario benchmarks are intentionally limited to the lowest-cost and highest-cost PnC configurations.

- ETH price: `$3000`
- Benchmark wrappers pause Foundry gas metering around setup/config construction and resume only for the target external call.
- Activation benchmarks exclude prerequisite ENSv2 namespace registry deployment.
- Mint and renewal scenarios are call-only and do not include post-call test assertions.
- Foundry execution gas does not include transaction intrinsic gas or calldata byte gas charged by the network.

## Activation Setup Benchmarks

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `activation.free_no_rules` | Activation with no rules, no payment, no hooks. | 282939 | $0.848817 |
| `activation.all_rules_split_five_resolver_writes` | Activation with every current rule, split payment, and five resolver writes. | 1345674 | $4.037022 |

## Call-Only Mint Benchmarks

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `mint.free_no_rules` | Controller mint with no rules, no payment, no hooks. | 224324 | $0.672972 |
| `mint.all_rules_split_five_resolver_writes` | Controller mint with every current rule, split payment, and five resolver writes. | 598700 | $1.796100 |

## Renewal Benchmarks

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `renew.free_no_rules` | Controller renewal with no rules, no payment, no hooks. | 85500 | $0.256500 |
| `renew.all_rules_split_five_resolver_writes` | Controller renewal with every current rule, split payment, and five resolver writes. | 399412 | $1.198236 |

## Direct ENSv2 Registry Baselines

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `registry.register_no_roles` | Direct ENSv2 registry register with owner, no buyer roles, no resolver. | 103061 | $0.309183 |
| `registry.register_buyer_roles` | Direct ENSv2 registry register with buyer roles and no resolver. | 150364 | $0.451092 |
| `registry.register_buyer_roles_resolver` | Direct ENSv2 registry register with buyer roles and resolver. | 154349 | $0.463047 |
| `registry.reserve_no_owner` | Direct ENSv2 registry reserve flow with owner set to zero. | 72316 | $0.216948 |
| `registry.renew_registered` | Direct ENSv2 registry renewal baseline. | 31132 | $0.093396 |
