# Namespace Issuance Gas Benchmarks

These benchmarks measure activation setup, end-to-end minting, renewal, and individual module function costs for the rule-based Namespace subname issuance architecture.

The minting benchmarks are end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured rules evaluate eligibility and price effects, the payment module settles funds, the official ENSv2 `PermissionedRegistry` mints the label, and post-hooks run when configured.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

## Assumptions

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`
- `Gas consumed @ 1 gwei` is the transaction fee in gwei at a 1 gwei gas price.
- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is root-only.
- Resolver record benchmarks use `BatchSetAddrToBuyerHook` so one hook module can execute multiple resolver writes.
- The legacy baseline lives at `benchmarks/baselines/policy-pricing-architecture.gas-snapshot` and represents the previous policy/pricing/processor architecture.

## Activation Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_activation_00_freeNoRules()` | free No Rules | 159995 | 159995 | $0.047999 | $0.239993 | $0.479985 | $1.439955 | $2.399925 |
| `testBenchmark_activation_01_defaultThreeRulesPaymentHook()` | default Three Rules Payment Hook | 476411 | 476411 | $0.142923 | $0.714617 | $1.429233 | $4.287699 | $7.146165 |
| `testBenchmark_activation_02_fullStackSevenRulesSplitPaymentFiveResolverWrites()` | full Stack Seven Rules Split Payment Five Resolver Writes | 947819 | 947819 | $0.284346 | $1.421728 | $2.843457 | $8.530371 | $14.217285 |

## Minting Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_mint_00_freeNoRules()` | free No Rules | 171332 | 171332 | $0.051400 | $0.256998 | $0.513996 | $1.541988 | $2.569980 |
| `testBenchmark_mint_01_defaultThreeRulesERC20PaymentHook()` | default Three Rules ERC20 Payment Hook | 302425 | 302425 | $0.090728 | $0.453637 | $0.907275 | $2.721825 | $4.536375 |
| `testBenchmark_mint_02_fullStackRulesSplitPaymentFiveResolverWrites()` | full Stack Rules Split Payment Five Resolver Writes | 590657 | 590657 | $0.177197 | $0.885986 | $1.771971 | $5.315913 | $8.859855 |

## Renewal Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_renew_00_defaultThreeRulesERC20Payment()` | default Three Rules ERC20 Payment | 193813 | 193813 | $0.058144 | $0.290720 | $0.581439 | $1.744317 | $2.907195 |

## Rule Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_rule_00_saleWindow_evaluateMint()` | sale Window evaluate Mint | 36023 | 36023 | $0.010807 | $0.054035 | $0.108069 | $0.324207 | $0.540345 |
| `testBenchmark_profile_rule_01_labelLength_evaluateMint()` | label Length evaluate Mint | 36192 | 36192 | $0.010858 | $0.054288 | $0.108576 | $0.325728 | $0.542880 |
| `testBenchmark_profile_rule_02_fixedPrice_evaluateMint()` | fixed Price evaluate Mint | 40669 | 40669 | $0.012201 | $0.061004 | $0.122007 | $0.366021 | $0.610035 |
| `testBenchmark_profile_rule_03_lengthPremium_evaluateMint()` | length Premium evaluate Mint | 43796 | 43796 | $0.013139 | $0.065694 | $0.131388 | $0.394164 | $0.656940 |
| `testBenchmark_profile_rule_04_tokenBalanceDiscount_evaluateMint()` | token Balance Discount evaluate Mint | 45766 | 45766 | $0.013730 | $0.068649 | $0.137298 | $0.411894 | $0.686490 |
| `testBenchmark_profile_rule_05_reservation10_evaluateMint()` | reservation10 evaluate Mint | 65880 | 65880 | $0.019764 | $0.098820 | $0.197640 | $0.592920 | $0.988200 |
| `testBenchmark_profile_rule_06_reservation1000_evaluateMint()` | reservation1000 evaluate Mint | 80829 | 80829 | $0.024249 | $0.121244 | $0.242487 | $0.727461 | $1.212435 |
| `testBenchmark_profile_rule_07_whitelist10_evaluateMint()` | whitelist10 evaluate Mint | 67819 | 67819 | $0.020346 | $0.101729 | $0.203457 | $0.610371 | $1.017285 |
| `testBenchmark_profile_rule_08_whitelist1000_evaluateMint()` | whitelist1000 evaluate Mint | 82703 | 82703 | $0.024811 | $0.124055 | $0.248109 | $0.744327 | $1.240545 |
| `testBenchmark_profile_rule_09_labelClassNumber_evaluateMint()` | label Class Number evaluate Mint | 30135 | 30135 | $0.009040 | $0.045202 | $0.090405 | $0.271215 | $0.452025 |
| `testBenchmark_profile_rule_10_usdOracle_evaluateMint()` | usd Oracle evaluate Mint | 47033 | 47033 | $0.014110 | $0.070550 | $0.141099 | $0.423297 | $0.705495 |

## Payment And Hook Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_hook_00_recordingPostHook_afterMint()` | recording Post Hook after Mint | 57561 | 57561 | $0.017268 | $0.086342 | $0.172683 | $0.518049 | $0.863415 |
| `testBenchmark_profile_hook_01_batchResolverHookFiveWrites_afterMint()` | batch Resolver Hook Five Writes after Mint | 127556 | 127556 | $0.038267 | $0.191334 | $0.382668 | $1.148004 | $1.913340 |
| `testBenchmark_profile_payment_00_collectMintERC20()` | collect Mint ERC20 | 66071 | 66071 | $0.019821 | $0.099107 | $0.198213 | $0.594639 | $0.991065 |
| `testBenchmark_profile_payment_01_collectMintSplitERC20()` | collect Mint Split ERC20 | 96851 | 96851 | $0.029055 | $0.145277 | $0.290553 | $0.871659 | $1.452765 |

## Baseline Comparison

| Scenario | Legacy benchmark | Legacy gas | Rule benchmark | Rule gas | Delta | Delta % |
| --- | --- | ---: | --- | ---: | ---: | ---: |
| Full-stack activation | `activation_13_compositePolicyCompositePricingDirectSplitFiveResolverWrites` | 893764 | `activation_02_fullStackSevenRulesSplitPaymentFiveResolverWrites` | 947819 | +54055 | +6.05% |
| Full-stack mint | `mint_18_fullStackCompositePolicyCompositePricingDirectSplitFiveResolverWrites` | 498340 | `mint_02_fullStackRulesSplitPaymentFiveResolverWrites` | 590657 | +92317 | +18.52% |

## Scenario Notes

| Area | Notes |
| --- | --- |
| Activations | Activation benchmarks call `NamespaceController.activate` with rule, payment, and hook configuration. |
| Minting | Minting benchmarks execute one `NamespaceController.mint` transaction after activation setup in `setUp()`. |
| Renewal | Renewal benchmarks execute one `NamespaceController.renew` transaction against a label minted during setup. |
| Rules | Rule profiles call each rule directly with realistic activation config so hotspots can be compared before optimizing internals. |
| Reservations | Reservation proof scenarios use the claim-based `ReservationRule`, which can block, buyer-bind, and override prices. |
| Whitelists | Whitelist proof scenarios use `WhitelistRule` claims, which can allow, block, discount, or add/override prices. |
| Resolver hooks | Resolver record benchmarks use one batched post-hook module for multiple addr writes. |
| Full stack | The full-stack benchmark uses seven rules, `ERC20SplitPaymentModule`, the official ENSv2 registry, and `BatchSetAddrToBuyerHook`. |
